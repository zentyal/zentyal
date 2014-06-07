#!/usr/bin/perl
#
# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Samba::SysvolSync;

use EBox::Global;
use EBox::Util::Random;

use TryCatch::Lite;
use Net::Ping;
use Net::DNS;
use Authen::Krb5::Easy qw{kinit kcheck kdestroy kerror kexpires};

use constant DEBUG => 0;

sub new
{
    my ($class) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $users = EBox::Global->modInstance('samba');
    my $sambaSettings = $users->model('DomainSettings');

    # Set kerberos ticket cache path
    my $ccache = EBox::Config::tmp() . 'sysvol-sync.ccache';
    my $keytab = EBox::Config::conf() . 'sysvol-sync.keytab';
    $ENV{KRB5CCNAME} = $ccache;

    # Remove old cache
    unlink $ccache if (-f $ccache);

    my $self = {
        keytab => $keytab,
        adUser => $sambaSettings->adminAccountValue(),
        destination => $sysinfo->fqdn(),
        hasTicket => 0,
    };

    bless ($self, $class);

    # Check source
    my $source = $sambaSettings->dcfqdnValue();
    $self->{source} = $self->checkSource($source);

    return $self;
}

sub extractKeytab
{
    my ($self, $keytab, $adminUser) = @_;

    my $ok = 1;
    my $zentyalUser = EBox::Config::user();
    my @cmds;
    push (@cmds, "rm -f $keytab");
    push (@cmds, "samba-tool domain exportkeytab $keytab " .
                 "--principal='$adminUser'");
    push (@cmds, "chown '$zentyalUser' '$keytab'");
    push (@cmds, "chmod 400 '$keytab'");

    try {
        my $ret = kdestroy();
        unless (defined $ret and $ret == 1) {
            EBox::error("kdestroy: " . kerror());
        }
        EBox::debug("Extracting keytab");
        EBox::Sudo::root(@cmds);
        $ok = kinit($keytab, $adminUser);
        if (defined $ok and $ok == 1) {
            EBox::info("Got ticket");
        } else {
            EBox::error("kinit error: " . kerror());
        }
    } catch ($error) {
        EBox::error("Could not extract keytab: $error");
        $ok = undef;
    }
    return $ok;
}

sub sourceReachable
{
    my ($self) = @_;

    my $source = $self->{source};
    my $pinger = Net::Ping->new('tcp', 2);
    $pinger->port_number(445);
    my $reachable = $pinger->ping($source);
    $pinger->close();
    return $reachable;
}

sub checkSource
{
    my ($self, $source) = @_;

    # If we have an IP as the source, reverse resolve to the FQDN. This is
    # required for kerberos to get the CIFS ticket.
    if (EBox::Validate::checkIP($source)) {
        my $resolver = new Net::DNS::Resolver(
            nameservers => ['127.0.0.1', $source]);
        my $target = join('.', reverse split(/\./, $source)).".in-addr.arpa";
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
            $source = $answer;
        } else {
            EBox::error("Could not reverse resolve DC IP $source to the FQDN");
            return undef;
        }
    }
    return $source;
}

sub sync
{
    my ($self, $debug) = @_;

    my $source = $self->{source};
    my $destination = $self->{destination};
    unless (defined $source and length $source) {
        EBox::error("Source not defined");
        return;
    }
    unless (defined $destination and length $destination) {
        EBox::error("Destination not defined");
        return;
    }

    # Try to ping the DC
    return unless ($self->sourceReachable());

    # Check if ticket is expired
    $self->{hasTicket} = kcheck($self->{keytab}, $self->{adUser});

    # Get ticket
    while (not $self->{hasTicket}) {
        EBox::info("No ticket or expired");
        $self->{hasTicket} = $self->extractKeytab($self->{keytab}, $self->{adUser});
        sleep (2);
    }

    # Sync share
    my $cmd = "net rpc share migrate files sysvol " .
              "-k --destination=$destination -S $source --acls";
    if ($debug) {
        $cmd .= " -v -d6 >> " . EBox::Config::tmp() . "sysvol-sync.output 2>&1";
    }

    EBox::info("Synchronizing sysvol share from $source");
    system ($cmd);
    if ($? == -1) {
        EBox::error("failed to execute: $!");
        return -1;
    } elsif ($? & 127) {
        my $signal = ($? & 127);
        EBox::error("child died with signal $signal");
        return $signal;
    } else {
        my $code = ($? >> 8);
        unless ($code == 0) {
            EBox::info("child exited with value $code");
            # Maybe user pwd has changed an we need to export keytab again
            $self->{hasTicket} = 0;
        }
        return $code;
    }
    return 0;
}

# Method: run
#
#   Run the daemon. It never dies.
#
sub run
{
    my ($self, $interval, $random) = @_;

    EBox::info("Samba sysvol synchronizer script started");

    while (1) {
        my $randomSleep = (DEBUG ? (3) : ($interval + int (rand ($random))));
        EBox::debug("Sleeping for $randomSleep seconds");
        sleep ($randomSleep);
        $self->sync(DEBUG);
    }

    kdestroy();
    EBox::info("Samba sysvol synchronizer script stopped");
}

if ($0 eq __FILE__) {
    EBox::init();

    # Run each 300 sec + random between (0,100) seconds
    my $synchronizer = new EBox::Samba::SysvolSync();
    $synchronizer->run(300, 100);
}

1;
