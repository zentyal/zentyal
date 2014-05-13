# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Module::LDAP;
use base qw(EBox::Module::Service);

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;

use TryCatch::Lite;

# Method: _ldapModImplementation
#
#   All modules using any of the functions in LdapUserBase.pm
#   should override this method to return the implementation
#   of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
sub _ldapModImplementation
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: ldap
#
#   Provides an EBox::Ldap object with the proper configuration for the
#   LDAP setup of this ebox
sub ldap
{
    my ($self) = @_;

    unless(defined($self->{ldap})) {
        $self->{ldap} = EBox::Global->modInstance('users')->newLDAP();
    }
    return $self->{ldap};
}

sub clearLdapConn
{
    my ($self) = @_;
    $self->{ldap} or return;
    $self->{ldap}->clearConn();
    $self->{ldap} = undef;
}

# Method: _loadSchemas
#
#  Load the *.ldif schemas contained in the module package
#
#
sub _loadSchemas
{
    my ($self) = @_;

    my $path = EBox::Config::share() . 'zentyal-' . $self->name();

    foreach my $attr (glob ("$path/*-attr.ldif")) {
        EBox::Sudo::root("/usr/share/zentyal-users/load-schema $attr");
    }
    foreach my $class (glob ("$path/*-class.ldif")) {
        EBox::Sudo::root("/usr/share/zentyal-users/load-schema $class");
    }
}

# Method: _regenConfig
#
#   Overrides <EBox::Module::Service::_regenConfig>
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    # FIXME: only if users is provisioned, do it only once
    # currently this requires a manual restart in the shell,
    # it's not triggered by enable + save changes
    $self->_loadSchemas();

    $self->SUPER::_regenConfig(@_);
}

# Method: reprovisionLDAP
#
#   Reprovision LDAP setup for the module.
#
sub reprovisionLDAP
{
}

# Method: slaveSetup
#
#  this is called when the slave setup. The slave setup is done when saving
#  changes so this is normally used to modify LDAP or other tasks which don't
#  change configuration.
#
#  The default implementation just calls reprovisionLDAP
#
# For changing configuration before the save changes we will use the
# preSlaveSetup methos which currently is only called for module mail
sub slaveSetup
{
    my ($self) = @_;
    $self->reprovisionLDAP();
}

# Method: preSlaveSetup
#
#  This is called to made change in the module when the server
#  is configured to enter in slave mode. Configuration changes
#  should be done there and will be committed in the next saving of changes.
#
# Parameters:
#  master - master type
#
sub preSlaveSetup
{
    my ($self, $master) = @_;
}

# Method: preSlaveSetup
#
# This method can be used to put a warning to be seen by the administrator
# before setting slave mode. The module should warn of nay destructive action
# entailed by the change of mode.
#
# Parameters:
#  master -master type
#
sub slaveSetupWarning
{
    my ($self, $master) = @_;
    return undef;
}

sub usersModesAllowed
{
    my ($self) = @_;
    my $users = $self->global()->modInstance('users');
    return [$users->STANDALONE_MODE()];
}

sub checkUsersMode
{
    my ($self) = @_;
    my $users = $self->global()->modInstance('users');
    my $mode = $users->mode();
    my $allowedMode = grep {
        $mode eq $_
    } @{ $self->usersModesAllowed() };
    if (not $allowedMode) {
        throw EBox::Exceptions::External(__x(
            'Module {mod} is uncompatible with the current users operation mode ({mode})',
            mod => $self->printableName(),
            mode => $users->model('Mode')->modePrintableName,
        ));
    }
}

1;
