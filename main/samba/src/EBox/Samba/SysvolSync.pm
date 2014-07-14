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
use EBox::Samba::AuthKrbHelper;

use TryCatch::Lite;
use Net::Ping;
use Net::DNS;
use Time::HiRes;
use POSIX;

my $LOGFILE = '/var/log/zentyal/samba-sysvolsync.log';

sub new
{
    my $class = shift;
    my %params = @_;

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
        destination => $sysinfo->fqdn(),
        debug => $params{debug},
    };

    bless ($self, $class);

    # Check source
    my $source = $sambaSettings->dcfqdnValue();
    $self->{source} = $self->checkSource($source);

    return $self;
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
            $self->logevent('ERROR', "Could not reverse resolve DC IP $source to the FQDN");
            return undef;
        }
    }
    return $source;
}

sub sync
{
    my ($self) = @_;

    my $source = $self->{source};
    my $destination = $self->{destination};
    my $keytab = $self->{keytab};
    unless (defined $source and length $source) {
        $self->logevent('ERROR', "Source not defined");
        return;
    }
    unless (defined $destination and length $destination) {
        $self->logevent('ERROR', "Destination not defined");
        return;
    }
    unless (defined $keytab and length $keytab) {
        $self->logevent('ERROR', "keytab not defined");
        return;
    }

    # Try to ping the DC
    return unless ($self->sourceReachable());

    # Get ticket
    my $krbHelper = undef;
    try {
        $krbHelper = new EBox::Samba::AuthKrbHelper(RID => 500, keytab => $keytab);
    } catch ($e) {
        $self->logevent('ERROR', "Could not get ticket: $e");
        return;
    }

    # Sync share
    my $cmd = "net rpc share migrate files sysvol " .
              "-k --destination=$destination -S $source --acls ";
    if ($self->debug()) {
        $cmd .= " -v -d6 ";
    }
    $cmd .= " >> $LOGFILE 2>&1";

    $self->logevent('INFO', "Synchronizing sysvol share from $source");
    $self->logevent('DEBUG', "Executing $cmd");
    system ($cmd);
    if ($? == -1) {
        $self->logevent('ERROR', "Failed to execute: $!");
        return -1;
    } elsif ($? & 127) {
        my $signal = ($? & 127);
        $self->logevent('ERROR', "Child died with signal $signal");
        return $signal;
    } else {
        my $code = ($? >> 8);
        unless ($code == 0) {
            $self->logevent('INFO', "child exited with value $code");
            # Maybe user pwd has changed an we need to export keytab again
            $self->{hasTicket} = 0;
        }
        return $code;
    }
    $self->logevent('INFO', "Synced from $source");

    return 0;
}

# Method: debug
#
#   Return true if debug enabled
#
sub debug
{
    my ($self) = @_;

    return $self->{debug};
}

# Method: logevent
#
#   Writes a message to log file
#
sub logevent
{
    my ($self, $type, $msg) = @_;

    return if ($type eq 'DEBUG' and not $self->debug());

    open (my $log, '>>', $LOGFILE);
    my ($x,$y) = Time::HiRes::gettimeofday();
    $y = sprintf("%06d", $y / 1000);
    my $timestamp = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime ($x)) . ".$y";
    print $log "$timestamp $type> $msg\n";
    close ($LOGFILE);
}

# Method: run
#
#   Run the daemon. It never dies.
#
sub run
{
    my ($self, $interval, $random) = @_;

    $self->logevent('INFO', "Samba sysvol synchronizer script started");

    while (1) {
        my $randomSleep = $interval + int (rand ($random));
        $self->logevent('DEBUG', "Sleeping for $randomSleep seconds");
        sleep ($randomSleep);
        $self->sync();
    }

    $self->logevent('INFO', "Samba sysvol synchronizer script stopped");
}

if ($0 eq __FILE__) {
    EBox::init();

    # Run each 300 sec + random between (0,100) seconds
    my $synchronizer = new EBox::Samba::SysvolSync();
    $synchronizer->run(300, 100);
}

1;
