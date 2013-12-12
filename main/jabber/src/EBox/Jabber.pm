# Copyright (C) 2005-2007 Warp Networks S.L
# Copyright (C) 2010-2011 Zentyal S.L.
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

package EBox::Jabber;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::LdapModule
            );

use EBox::Global;
use EBox::Gettext;
use EBox::JabberLdapUser;
use EBox::Exceptions::DataExists;

use constant EJABBERDCONFFILE => '/etc/ejabberd/ejabberd.cfg';
use constant JABBERPORT => '5222';
use constant JABBERPORTSSL => '5223';
use constant JABBERPORTS2S => '5269';
use constant JABBERPORTSTUN => '3478';
use constant JABBERPORTPROXY => '7777';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'jabber',
                                      printableName => 'Jabber',
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('Add Jabber LDAP schema'),
            'reason' => __('Zentyal will need this schema to store Jabber users.'),
            'module' => 'jabber'
        },
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
        {
            'file' => EJABBERDCONFFILE,
            'module' => 'jabber',
            'reason' => __('To properly configure ejabberd.')
        },
    ];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'jabber';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('Jabber Server'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'deny');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

sub _services
{
    return [
             { # jabber c2s
                 'protocol' => 'tcp',
                 'sourcePort' => 'any',
                 'destinationPort' => '5222',
             },
             { # jabber c2s
                 'protocol' => 'tcp',
                 'sourcePort' => 'any',
                 'destinationPort' => '5223',
             },
    ];
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    my ($self) = @_;

    return [
        'EBox::Jabber::Model::GeneralSettings',
        'EBox::Jabber::Model::JabberUser',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::Jabber::Composite::General',
    ];
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ejabberd',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/ejabberd/ejabberd.pid']
        }
    ];
}

# Method: _setConf
#
#       Overrides base method. It writes the jabber service configuration
#
sub _setConf
{
    my ($self) = @_;

    my @array = ();

    my $jabuid = (getpwnam('ejabberd'))[2];
    my $jabgid = (getpwnam('ejabberd'))[3];

    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->ldap();
    my $ldapconf = $ldap->ldapConf;

    my $settings = $self->model('GeneralSettings');
    my $jabberldap = new EBox::JabberLdapUser;

    push(@array, 'domain' => $settings->domainValue());
    push(@array, 'admins' => $jabberldap->getJabberAdmins());
    push(@array, 'ssl' => $settings->sslValue());
    push(@array, 's2s' => $settings->s2sValue());
    push(@array, 'muc' => $settings->mucValue());

    push(@array, 'ldapsrv' => '127.0.0.1');
    unless ($users->mode() eq 'slave') {
        push(@array, 'ldapport', $ldapconf->{'port'});
    } else {
        push(@array, 'ldapport', $ldapconf->{'translucentport'});
    }
    push(@array, 'ldapbase' => $ldapconf->{'dn'});
    $self->writeConfFile(EJABBERDCONFFILE,
                 "jabber/ejabberd.cfg.mas",
                 \@array, { 'uid' => $jabuid, 'gid' => $jabgid, mode => '640' });
}

# Method: menu
#
#       Overrides EBox::Module method.
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'Jabber/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Communications',
                                    'order' => 620));
}

# Method: _ldapModImplementation
#
#      All modules using any of the functions in LdapUserBase.pm
#      should override this method to return the implementation
#      of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
#
sub _ldapModImplementation
{
    return new EBox::JabberLdapUser();
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issue for this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       service - name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#
sub certificates
{
    my ($self) = @_;

    return [
        {
             service =>  __('Jabber Server'),
             path    =>  '/etc/ejabberd/ejabberd.pem',
             user => 'root',
             group => 'ejabberd',
             mode => '0440',
        },
    ];
}

# Method: fqdn
#FIXME doc
sub fqdn
{
    my $fqdn = `hostname --fqdn`;
    if ($? != 0) {
        $fqdn = 'ebox.localdomain';
    }
    chomp $fqdn;
    return $fqdn;
}

1;
