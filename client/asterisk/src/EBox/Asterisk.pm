# Copyright (C) 2008 eBox Technologies S.L.
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


# Class: EBox::Asterisk
#
#   TODO: Documentation

package EBox::Asterisk;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::LdapModule);

use EBox::Global;
use EBox::Gettext;
use EBox::AsteriskLdapUser;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'asterisk',
            printableName => __('Asterisk'),
            domain => 'ebox-asterisk',
            @_);

    bless($self, $class);
    return $self;
}


# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::Asterisk::Model::GeneralSettings',
        'EBox::Asterisk::Model::Provider',
    ];
}


# Method: compositeClasses
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return ['EBox::Asterisk::Composite::General'];
}


# Method: usedFiles
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => '/etc/asterisk/modules.conf',
                        'module' => 'asterisk',
                        'reason' => __('To configure Asterisk enabled and disabled modules.')
                      });

    push (@usedFiles, { 'file' => '/etc/asterisk/sip.conf',
                        'module' => 'asterisk',
                        'reason' => __('To configure the SIP trunk for local users and external providers.')
                      });

    push (@usedFiles, { 'file' => '/etc/asterisk/extconfig.conf',
                        'module' => 'asterisk',
                        'reason' => __('To configure the Realtime interface.')
                      });

    push (@usedFiles, { 'file' => '/etc/asterisk/res_ldap.conf',
                        'module' => 'asterisk',
                        'reason' => __('To configure the LDAP Realtime driver.')
                      });

    push (@usedFiles, { 'file' => '/etc/asterisk/extensions.conf',
                        'module' => 'asterisk',
                        'reason' => __('To configure the Asterisk dialplan.')
                      });

    push (@usedFiles, {
                        'file' => '/etc/ldap/slapd.conf',
                        'reason' => __('To add a new schema'),
                        'module' => 'users'
                      });

    return \@usedFiles;
}


# Method: enableActions
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    EBox::Sudo::root(EBox::Config::share() .
                     '/ebox-asterisk/ebox-asterisk-enable');
}


# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.asterisk'
        }
    ];
}


# Method: enableService
#
# Overrides:
#
#       <EBox::Module::Service::enableService>
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    #$self->configureFirewall(); FIXME
}


# Method: _setConf
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my $self = shift;
    my @array = ();
}


# Method: _ldapModImplementation
#
sub _ldapModImplementation
{
    return new EBox::AsteriskLdapUser();
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $item = new EBox::Menu::Item(
            'url' => 'Asterisk/Composite/General',
            'text' => __('Asterisk'));

    $root->add($item);
}

1;
