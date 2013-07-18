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

package EBox::Samba::SysvolSync;

use EBox::Global;
use EBox::Util::Random;
use EBox::Samba::SmbClient;

use Error qw(:try);
use Errno;
use Net::Ping;
use Net::DNS;

use constant DEBUG => 0;

sub new
{
    my ($class) = @_;

    my $self = {};
    bless ($self, $class);

    return $self;
}

sub getSourceDC
{
    my ($self) = @_;

    my $sambaModule = EBox::Global->modInstance('samba');
    my $settingsModel = $sambaModule->model('GeneralSettings');
    my $src = $settingsModel->dcfqdnValue();

    return $self->checkDC($src);
}

sub getDestinationDC
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $dst = $sysinfo->fqdn();

    return $self->checkDC($dst);
}

sub dcReachable
{
    my ($self, $dc) = @_;

    my $pinger = Net::Ping->new('tcp', 2);
    $pinger->service_check(1);
    $pinger->port_number(445);
    my $reachable = $pinger->ping($dc);
    $pinger->close();

    return $reachable;
}

sub checkDC
{
    my ($self, $dc) = @_;

    # If we have an IP as the source, reverse resolve to the FQDN. This is
    # required for kerberos to get the CIFS ticket.
    if (EBox::Validate::checkIP($dc)) {
        my $resolver = new Net::DNS::Resolver(nameservers => ['127.0.0.1']);
        my $target = join('.', reverse split(/\./, $dc)).".in-addr.arpa";
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
            $dc = $answer;
        } else {
            throw EBox::Exceptions::Internal(
                "Could not reverse resolve DC IP $dc to the FQDN");
        }
    }

    unless ($self->dcReachable($dc)) {
        throw EBox::Exceptions::Internal("DC $dc is not reachable");
    }
    return $dc;
}

sub copyEntry
{
    my ($self, $smb, $entry) = @_;

    my $srcURL = "$entry->{srcBase}/$entry->{name}";
    my $dstURL = "$entry->{dstBase}/$entry->{name}";
    my $dstSD = $entry->{sd};

    if ($entry->{type} == Filesys::SmbClient::SMBC_DIR) {
        if ($smb->mkdir($dstURL, '0666') != 1) {
            # Ignore already exists error
            if ($! != Errno::EEXIST) {
                throw EBox::Exceptions::Internal("mkdir: $!");
            }
        }
        if ($smb->set_xattr($dstURL, "system.nt_sec_desc.*", $dstSD) != 1) {
            throw EBox::Exceptions::Internal("setxattr: $!");
        }
    } elsif ($entry->{type} == Filesys::SmbClient::SMBC_FILE) {
        if ($smb->smb_copy($srcURL, $dstURL) != 1) {
            throw EBox::Exceptions::Internal("smb_copy: $!");
        }
        if ($smb->set_xattr($dstURL, "system.nt_sec_desc.*", $dstSD) != 1) {
            throw EBox::Exceptions::Internal("setxattr: $!");
        }
    }
}

sub syncDirectory
{
    my ($self, $smb, $srcURL, $dstURL) = @_;

    my $srcFD = $smb->opendir($srcURL) or
        throw EBox::Exceptions::Internal("opendir: $!");

    while (my $f = $smb->readdir_struct($srcFD)) {
        my $type = @{$f}[0];
        my $name = @{$f}[1];
        my $comment = @{$f}[2];
        my $sd = $smb->get_xattr("$srcURL/$name", "system.nt_sec_desc.*");

        my $entry = {
            srcBase => $srcURL,
            dstBase => $dstURL,
            type    => $type,
            name    => $name,
            comment => $comment,
            sd      => $sd,
        };

        if ($name ne '.' and $name ne '..') {
            $self->copyEntry($smb, $entry);
            if ($type == Filesys::SmbClient::SMBC_DIR) {
                $self->syncDirectory($smb, "$srcURL/$name", "$dstURL/$name");
            }
        }
    }
    $smb->close($srcFD);
}

sub sync
{
    my ($self) = @_;

    try {
        my $srcDC = $self->getSourceDC();
        my $dstDC = $self->getDestinationDC();

        EBox::info("Synchronizing sysvol from $srcDC to $dstDC");
        my $smb = new EBox::Samba::SmbClient(RID => 500);
        my $srcURL = "smb://$srcDC/sysvol";
        my $dstURL = "smb://$dstDC/sysvol";
        $self->syncDirectory($smb, $srcURL, $dstURL);
    } otherwise {
    };
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
        sleep ($randomSleep);
        $self->sync();
    }

    EBox::info("Samba sysvol synchronizer script stopped");
}

if ($0 eq __FILE__) {
    EBox::init();

    # Run each 300 sec + random between (0,100) seconds
    my $synchronizer = new EBox::Samba::SysvolSync();
    $synchronizer->run(300, 100);
}

1;
