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
        $self->{ldap} = $self->global()->modInstance('users')->newLDAP();
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

    my $name = $self->name();
    my $global = $self->global();
    my $path = EBox::Config::share() . "zentyal-$name";

    foreach my $attr (glob ("$path/*-attr.ldif")) {
        EBox::Sudo::root("/usr/share/zentyal-users/load-schema $attr");
    }
    foreach my $class (glob ("$path/*-class.ldif")) {
        EBox::Sudo::root("/usr/share/zentyal-users/load-schema $class");
    }

    if ($name eq 'users') {
        $global->addModuleToPostSave('users');
    } else {
        $global->modInstance('users')->restartService();
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

    if ($self->global()->modInstance('users')->isProvisioned()) {
        $self->_performSetup();
        $self->SUPER::_regenConfig(@_);
    } elsif ($self->name() eq 'users') {
        # If not provisioned but we are saving the users
        # module, let do the provision first
        $self->SUPER::_regenConfig(@_);
        $self->_performSetup();
    }
}

sub _performSetup
{
    my ($self) = @_;

    my $state = $self->get_state();
    unless ($state->{'_schemasAdded'}) {
        $self->_loadSchemas();
        $state->{'_schemasAdded'} = 1;
        $self->set_state($state);
    }

    unless ($state->{'_ldapSetup'}) {
        $self->setupLDAP();
        $state->{'_ldapSetup'} = 1;
        $self->set_state($state);
    }
}

sub setupLDAP
{
}

sub setupLDAPDone
{
    my ($self) = @_;
    my $state = $self->get_state();
    return $state->{'_schemasAdded'} and $state->{'_ldapSetup'};
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
