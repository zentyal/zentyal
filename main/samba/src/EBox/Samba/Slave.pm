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
# Class: EBox::Samba::Slave
#
#    These methods will be called when a user or group is added,
#    modified or deleted. They can be implemented in order to sync
#    that changes to other machines (master provider).
#
package EBox::Samba::Slave;

use base 'EBox::LdapUserBase';

use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use TryCatch::Lite;
use File::Temp qw/tempfile/;
use Time::HiRes qw(gettimeofday);
use JSON::XS;
use File::Slurp;
use EBox::Samba::LdapObject;
use EBox::Samba::Group;
use EBox::Samba::User;

use constant PENDING_REMOVAL_KEY => 'slaves_to_remove';

# Method: new
#
#   Create a new slave instance, choosen name should
#   be unique between all the slaves
#
sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    $self->{name} = delete $opts{name};
    unless (defined($self->{name})) {
        throw EBox::Exceptions::Internal('No name provided');
    }

    bless($self, $class);
    return $self;
}

# Method: sync
#
#   Synchronize an action to the slave.
#   If something fails (for example, connectivity) the action
#   will be saved for later, and synchronized by slaves-sync daemon
#
sub sync
{
    my ($self, $signal, $args) = @_;

    try {
        my $method = '_' . $signal;
        $self->$method(@{$args});
    } catch ($e) {
        # Sync failed, save pending action
        my $name = $self->name();
        EBox::error("Error notifying $name for $signal: $e");
        $self->savePendingSync($signal, $args);
    }
}

# method: savePendingSync
#
#   Save a sync operation which failed, later slave-sync should
#   retry it by using syncFromFile
#
sub savePendingSync
{
    my ($self, $signal, $args) = @_;

    my $users = EBox::Global->modInstance('samba');
    my $dir = $users->syncJournalDir($self);

    my $time = join('', gettimeofday());
    my ($fh, $filename) = tempfile("$time-$signal-XXXX", DIR => $dir);

    $self->writeActionInfo($fh, $signal, $args);

    $fh->close();
}

sub writeActionInfo
{
    my ($self, $fh, $signal, $args) = @_;

    my @params;
    foreach my $arg (@{$args}) {
        if (ref($arg) =~ /::/) {
            if ($arg->isa('EBox::Samba::LdapObject')) {
                my @lines = split(/\n/, $arg->as_ldif());
                $arg = {
                    class => ref($arg),
                    ldif => \@lines,
                };
            }
        }

        push (@params, $arg);
    }

    # JSON encode args
    my $action = {
        signal => $signal,
        args   => \@params,
    };

    print $fh encode_json($action);
}

# method: syncFromFile
#
#   Try to sync a saved action from a previous failed sync
#
sub syncFromFile
{
    my ($self, $file) = @_;

    my $action = $self->readActionInfo($file);

    my $method = '_' . $action->{signal};
    my $args = $action->{args};

    try {
        $self->$method(@{$args});
        unlink ($file);
    } catch ($e) {
        my $name = $self->name();
        EBox::error("Error notifying $name for $method: $e");
    }
}

sub readActionInfo
{
    my ($self, $file) = @_;

    my $action = decode_json(read_file($file));

    my $signal = $action->{signal};
    my $args = $action->{args};

    my @params;
    foreach my $arg (@{$args}) {
        if (ref($arg) eq 'HASH') {
            # Import LDIF
            my ($fh, $ldif) = tempfile(UNLINK => 1);
            print $fh join("\n", @{$arg->{ldif}});
            $fh->close();

            my $class = $arg->{class};
            $arg = $class->new(ldif => $ldif);
        }
        push (@params, $arg);
    }

    $action->{args} = \@params;

    return $action;
}

sub name
{
    my ($self) = @_;
    return $self->{name};
}

sub directory
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('samba');
    my $dir = $users->syncJournalDir($self, 1);
    return $dir;
}

sub removeDirectory
{
    my ($self) = @_;
    my $name = $self->name();
    my $dir = $self->directory();
    EBox::info("Removing sync dir for slave $name : $dir");
    EBox::Sudo::root("rm -rf $dir");
}

sub addRemoval
{
    my ($class, $id) = @_;
    my $users = EBox::Global->getInstance(1)->modInstance('samba');
    my $state = $users->get_state();
    if (not exists $state->{PENDING_REMOVAL_KEY}) {
        $state->{PENDING_REMOVAL_KEY} = [];
    }
    push @{$state->{PENDING_REMOVAL_KEY}}, $id;
    $users->set_state($state);
}

sub commitRemovals
{
    my ($class, $global) = @_;
    my $users = $global->modInstance('samba');
    my $slaveList = $users->model('Slaves');
    my $state = $users->get_state();
    my $list = delete  $state->{PENDING_REMOVAL_KEY};
    foreach my $id (@{ $list }) {
        # more safety: check if really the slave is not in the list
        if (defined $slaveList->row($id)) {
            next;
        }

        my $slave = new EBox::Samba::Slave(name => $id);
        $slave->removeDirectory();
    }
    $users->set_state($state);
}

sub revokeRemovals
{
    my ($class, $global) = @_;
    my $users = $global->modInstance('samba');
    my $state = $users->get_state();
    delete  $state->{PENDING_REMOVAL_KEY};
    $users->set_state($state);
}

1;
