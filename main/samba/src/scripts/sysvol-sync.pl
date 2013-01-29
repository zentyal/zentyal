#!/usr/bin/perl
#
# Copyright (C) 2012 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

use EBox::Global;
use EBox::Util::Random;

use Error qw(:try);
use Net::Ping;
use Net::DNS;
use Authen::Krb5::Easy qw{kinit kcheck kdestroy kerror kexpires};

use constant DEBUG => 1;

sub extractKeytab
{
    my ($keytab, $adminUser) = @_;

    my $ok = 1;
    my $zentyalUser = EBox::Config::user();
    my @cmds;
    push (@cmds, "rm -f $keytab");
    push (@cmds, "samba-tool domain exportkeytab $keytab " .
                 "--principal='$adminUser'");
    push (@cmds, "chown '$zentyalUser' '$keytab'");
    push (@cmds, "chmod 400 '$keytab'");

    try {
        kdestroy();
        EBox::debug("Extracting keytab");
        EBox::Sudo::root(@cmds);
        $ok = kinit($keytab, $adminUser);
        if (defined $ok and $ok == 1) {
            EBox::info("Got ticket");
        } else {
            EBox::error("kinit error: " . kerror());
        }
    } otherwise {
        my ($error) = @_;
        EBox::error("Could not extract keytab: $error");
        $ok = undef;
    };
    return $ok;
}

EBox::init();
EBox::info("Samba sysvol synchronizer script started");

my $sysinfo = EBox::Global->modInstance('sysinfo');
my $hostFQDN = $sysinfo->fqdn();

my $samba = EBox::Global->modInstance('samba');
my $sambaSettings = $samba->model('GeneralSettings');
my $sourceDC = $sambaSettings->dcfqdnValue();
my $mode = $sambaSettings->modeValue();
my $adc  = $sambaSettings->MODE_ADC();
my $adminUser = $sambaSettings->adminAccountValue();
my $hasTicket = 0;

my $pinger = Net::Ping->new('tcp', 2);
$pinger->port_number(445);

# If we have an IP as the source, reverse resolve to the FQDN. This is
# required for kerberos to get the CIFS ticket.
if (EBox::Validate::checkIP($sourceDC)) {
    my $resolver = new Net::DNS::Resolver(
        nameservers => ['127.0.0.1', $sourceDC]);
    my $target = join('.', reverse split(/\./, $sourceDC)).".in-addr.arpa";
    my $answer = '';
    my $query = $resolver->query($target, 'PTR');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq 'PTR';
            $answer = $rr->ptrdname();
            last;
        }
    }
    if (length $answer) {
        $sourceDC = $answer;
    } else {
        EBox::error("Could not reverse resolve DC IP $sourceDC to the FQDN");
        exit 1;
    }
}

# Set kerberos ticket cache path
my $ccache = EBox::Config::tmp() . 'sysvol-sync.ccache';
my $keytab = EBox::Config::conf() . 'sysvol-sync.keytab';
$ENV{KRB5CCNAME} = $ccache;

while (1) {
    # The script will be executed each 300 to 600 seconds, or 5 seconds if
    # debug is enabled
    my $randomSleep = (DEBUG ? (3) : (300 + int (rand (300))));
    EBox::debug("Sleeping for $randomSleep seconds");
    sleep ($randomSleep);

    # Do nothing if server not provisioned and module enabled
    next unless ($samba->isEnabled() and $samba->isProvisioned());

    # Do nothing if server is not an additional DC
    next unless ($mode eq $adc);

    # Try to ping the DC
    EBox::debug("Trying to ping $sourceDC\n");
    unless ($pinger->ping($sourceDC)) {
        EBox::warn("$sourceDC is not reachable");
        next;
    }

    # Check if ticket is expired
    $hasTicket = kcheck($keytab, $adminUser);

    # Get ticket
    while (not $hasTicket) {
        EBox::info("No ticket or expired");
        $hasTicket = extractKeytab($keytab, $adminUser);
        sleep (2);
    }

    # Sync share
    my $cmd = "net rpc share migrate files sysvol " .
        "-k --destination=$hostFQDN -S $sourceDC --acls";
    if (DEBUG) {
        $cmd .= " >> " . EBox::Config::tmp() . "sysvol-sync.output 2>&1";
    }

    EBox::info("Synchronizing sysvol share from $sourceDC");
    system ($cmd);
    if ($? == -1) {
        EBox::error("failed to execute: $!");
    } elsif ($? & 127) {
        my $signal = ($? & 127);
        EBox::error("child died with signal $signal");
    } else {
        my $code = ($? >> 8);
        unless ($code == 0) {
            EBox::info("child exited with value $code");
            # Maybe user pwd has changed an we need to export keytab again
            $hasTicket = 0;
        }
    }
}

kdestroy();
EBox::info("Samba sysvol synchronizer script stopped");

exit 0;
