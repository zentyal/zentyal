# Copyright (C) 2009-2010 eBox Technologies S.L.
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


# Class: EBox::EGroupware
#
#   TODO: Documentation

package EBox::EGroupware;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::LdapModule);

use Digest::MD5;

use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::EGroupwareLdapUser;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

use constant PORT => 80;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'egroupware',
            printableName => __n('Groupware'),
            domain => 'ebox-egroupware',
            @_);
}

## api functions

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::EGroupware::Model::VMailDomain',
        'EBox::EGroupware::Model::Applications',
        'EBox::EGroupware::Model::DefaultApplications',
        'EBox::EGroupware::Model::PermissionTemplates',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return ['EBox::EGroupware::Composite::General'];
}


sub domain
{
    return 'ebox-egroupware';
}

# Method: actions
#
#   Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    return [
    {
        'action' => __('Create PostgreSQL user egroupware'),
        'reason' => __('This user will be the owner of the egroupware database'),
        'module' => 'egroupware'
    },
    {
        'action' => __('Create PostgreSQL egroupware database'),
        'reason' => __('This database will store the data needed by eGroupware'),
        'module' => 'egroupware'
    }
    ];
}


# Method: usedFiles
#
#   Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => '/var/lib/egroupware/header.inc.php',
                        'module' => 'egroupware',
                        'reason' => __('To configure eGroupware access settings')
                      });

    push (@usedFiles, { 'file' => '/etc/postgresql/8.4/main/pg_hba.conf',
                        'module' => 'egroupware',
                        'reason' => __('To allow local access to egroupware database')
                      });

    return \@usedFiles;
}

# Method: enableActions
#
#   Override EBox::ServiceModule::ServiceInterface::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    # Generate password
    EBox::Sudo::root(EBox::Config::share() .
                    '/ebox-egroupware/ebox-init-egroupware init');

    # Write the generated password
    $self->_setConf();

    EBox::Sudo::root(EBox::Config::share() .
                     '/ebox-egroupware/ebox-egroupware-enable');

    # Install all languages by default
    EBox::Sudo::root(EBox::Config::share() .
                     '/ebox-egroupware/ebox-egroupware-install-all-languages');

    # Migrate existing users
    EBox::Sudo::root(EBox::Config::share() .
                    '/ebox-egroupware/ebox-init-egroupware migrate');
}

# Method: addModuleStatus
#
#   Overrides EBox::Module::Service::addModuleStatus
#
sub addModuleStatus
{
}

# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;

    my $settings = new EBox::Menu::Item(
            'url' => 'EGroupware/Composite/General',
            'text' => $self->printableName(),
            'separator' => 'Office',
            'order' => 560);

    $root->add($settings);
}


# Private functions

# Method: _ldapModImplementation
#
sub _ldapModImplementation
{
    return new EBox::EGroupwareLdapUser();
}


# Method: _setConf
#
#       This method uses a mason template to generate and write the
#       configuration for /var/lib/egroupware/header.inc.php
#
sub _setConf
{
    my ($self) = @_;

    my $username = 'ebox';
    my $password = getPassword();
    my $md5pass = Digest::MD5::md5_hex($password);

    $self->writeConfFile('/var/lib/egroupware/header.inc.php',
                         '/egroupware/header.inc.php.mas',
                         [ header_passwd => $md5pass,
                           config_user => $username,
                           config_passwd => $md5pass,
                           db_pass => getPassword()]);

    $self->_update();
    $self->_setAuth();
    $self->_configVDomain();
}

sub _update
{
    my ($self) = @_;

    my $path = EBox::Config::share() . '/ebox-egroupware';
    EBox::Sudo::root("$path/ebox-egroupware-update-db");
}

sub _setAuth
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->ldap();
    my $rootdn = $ldap->rootDn();
    my $password = $ldap->getPassword();
    my $usersdn = $users->usersDn();
    my $groupsdn = $users->groupsDn();
    my $ldapHost = '127.0.0.1:';
    unless ($users->mode() eq 'slave') {
        $ldapHost .= $ldap->ldapConf->{'port'};
    } else {
        $ldapHost .= $ldap->ldapConf->{'translucentport'};
    }

    my $path = EBox::Config::share() . '/ebox-egroupware';
    EBox::Sudo::root("$path/ebox-egroupware-set-auth '$rootdn' '$password' '$usersdn' '$groupsdn' '$ldapHost'");
}

sub _configVDomain
{
    my ($self) = @_;

    my $model = $self->model('VMailDomain');
    my $vdomain = $model->vdomainValue();

    unless (defined($vdomain) and ($vdomain ne '_unset_')) {
        return;
    }

    my $path = EBox::Config::share() . '/ebox-egroupware';
    EBox::Sudo::root("$path/ebox-egroupware-set-vdomain $vdomain");
}

# Method: getPassword
#
#       Returns the eGroupware admin password
#
# Returns:
#
#       string - password
#
# Exceptions:
#
#       Internal - If password can't be read
sub getPassword {

    my $path = EBox::Config->conf . "/ebox-egroupware.passwd";
    open(PASSWD, $path) or
        throw EBox::Exceptions::Internal("Could not open $path to " .
                "get egroupware password");

    my $pwd = <PASSWD>;
    close(PASSWD);

    $pwd =~ s/[\n\r]//g;

    return $pwd;
}

1;
