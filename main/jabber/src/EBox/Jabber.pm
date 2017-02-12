# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Jabber;

use base qw(
    EBox::Module::Kerberos
);

use EBox::Global;
use EBox::Gettext;
use EBox::JabberLdapUser;
use EBox::Exceptions::DataExists;
use EBox::Samba::User;

use TryCatch;

use constant EJABBERDCONFFILE => '/etc/ejabberd/ejabberd.yml';
use constant JABBERPORT => '5222';
use constant JABBERPORTSSL => '5223';
use constant JABBERPORTS2S => '5269';
use constant JABBERPORTSTUN => '3478';
use constant JABBERPORTPROXY => '7777';
use constant EJABBERD_CTL => '/usr/sbin/ejabberdctl';
use constant EJABBERD_DB_DIR =>  '/var/lib/ejabberd';

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
        my $services = EBox::Global->modInstance('network');

        my $serviceName = 'jabber';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'Jabber',
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

# Method: setupLDAP
#
# Overrides: <EBox::Module::LDAP::setupLDAP>
#
sub setupLDAP
{
    EBox::Sudo::root('/usr/share/zentyal-jabber/jabber-ldap update');
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

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [ { 'name' => 'ejabberd' } ];
}

# overriden because ejabberd process could be up and not be running
sub isRunning
{
    my ($self) = @_;
    my $stateCmd = 'LANG=C '. EJABBERD_CTL . ' status';
    my $output;
    try {
        $output =  EBox::Sudo::root($stateCmd);
    } catch (EBox::Exceptions::Sudo::Command $e) {
        # output will be undef
    }

    if (not $output) {
        return 0;
    }

    foreach my $line (@{ $output }) {
        if ($line =~ m/is running in that node/) {
            return 1;
        }
    }

    return 0;
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

    my $users = EBox::Global->modInstance('samba');
    my $ldap = $users->ldap();
    my $dse = $ldap->rootDse();
    my $defaultNC = $dse->get_value('defaultNamingContext');
    my $ldapconf = $ldap->ldapConf;
    my $sysinfo = $self->global->modInstance('sysinfo');

    my $settings = $self->model('GeneralSettings');
    my $jabberldap = new EBox::JabberLdapUser;

    my $domain = $settings->domainValue();

    push(@array, 'ldapHost' => '127.0.0.1');
    push(@array, 'ldapPort' => $ldapconf->{'port'});
    push(@array, 'ldapBase' => $ldap->dn());
    push(@array, 'ldapRoot' => $self->_kerberosServiceAccountDN());
    push(@array, 'ldapPasswd' => $self->_kerberosServiceAccountPassword());
    push(@array, 'usersDn' => $defaultNC);

    push(@array, 'domain' => $domain);
    push(@array, 'ssl' => $settings->sslValue());
    push(@array, 's2s' => $settings->s2sValue());

    push(@array, 'admins' => $jabberldap->getJabberAdmins());

    push(@array, 'muc' => $settings->mucValue());
    push(@array, 'stun' => $settings->stunValue());
    push(@array, 'proxy' => $settings->proxyValue());
    push(@array, 'sharedroster' => $settings->sharedrosterValue());
    push(@array, 'vcard' => $settings->vcardValue());

    $self->writeConfFile(EJABBERDCONFFILE,
                 "jabber/ejabberd.yml.mas",
                 \@array, { 'uid' => $jabuid, 'gid' => $jabgid, mode => '640' });

    if ($self->_domainChanged($domain)) {
        $self->_clearDatabase();
    }
}

# Method: menu
#
#       Overrides EBox::Module method.
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'Jabber/Composite/General',
                                    'text' => $self->printableName(),
                                    'icon' => 'jabber',
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
             serviceId => 'Jabber Server',
             service =>  __('Jabber Server'),
             path    =>  '/etc/ejabberd/ejabberd.pem',
             user => 'root',
             group => 'ejabberd',
             mode => '0440',
             includeCA => 1,
        },
    ];
}

sub _domainChanged
{
    my ($self, $newDomain) = @_;

    my $jabberRO = EBox::Global->getInstance(1)->modInstance('jabber');
    my $oldDomain = $jabberRO->model('GeneralSettings')->domainValue();

    return 0 unless (defined ($newDomain) and defined ($oldDomain));

    return ($newDomain ne $oldDomain);
}

sub _clearDatabase
{
    my ($self) = @_;

    $self->setAsChanged(1);
    $self->stopService();

    killProcesses();
    sleep 3;
    killProcesses(1);

    EBox::Sudo::root('rm -rf ' . EJABBERD_DB_DIR);
}

sub killProcesses
{
    my ($force) = @_;
    my @kill;
    foreach my $process (qw(beam epms)) {
        `pgrep $process`;
        if ($? == 0) {
            push @kill, $process;
        }
    }
    @kill or return;

    if ($force) {
        system "killall -9 @kill";
    } else {
        system "killall  @kill";
    }
}

# Method: _kerberosServicePrincipals
#
#   EBox::Module::Kerberos implementation. We don't create any SPN, just
#   the service account to bind to LDAP
#
sub _kerberosServicePrincipals
{
    return undef;
}

sub _kerberosKeytab
{
    return undef;
}

1;
