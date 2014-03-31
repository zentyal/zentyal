# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::UserCorner;

use base qw(EBox::Module::Service EBox::HAProxy::ServiceBase);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Root;
use EBox::UserCorner;
use EBox::UserCorner::Middleware::AuthLDAP;
use EBox::Util::Version;

use constant USERCORNER_USER  => 'ebox-usercorner';
use constant USERCORNER_GROUP => 'ebox-usercorner';
use constant USERCORNER_UPSTART_NAME => 'zentyal.usercorner-uwsgi';
use constant USERCORNER_NGINX_FILE => '/var/lib/zentyal-usercorner/conf/usercorner-nginx.conf';
use constant USERCORNER_LDAP_PASS => '/var/lib/zentyal-usercorner/conf/ldap_ro.passwd';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name          => 'usercorner',
        printableName => __('User Corner'),
        @_);

    bless($self, $class);
    return $self;
}

# Method: usercornerdir
#
#      Get the path to the usercorner directory
#
# Returns:
#
#      String - the path to that directory
sub usercornerdir
{
    return EBox::Config->var() . 'lib/zentyal-usercorner/';
}

# Method: usersessiondir
#
#      Get the path where user Web session identifiers are stored
#
# Returns:
#
#      String - the path to that directory
sub usersessiondir
{
    return usercornerdir() . 'sids/';
}

# Method: journalDir
#
#      Get the path where operation files are stored for master/slave sync
#
# Returns:
#
#      String - the path to that directory
sub journalDir
{
 return EBox::UserCorner::usercornerdir() . 'syncjournal';
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    my ($self) = @_;

    my @actions;
    push (@actions,
            {
             'action' => __('Migrate configured modules'),
             'reason' => __('Required for usercorner access to configured modules'),
             'module' => 'usercorner'
            });

    push (@actions,
            {
             'action' => __('Create directories for slave journals'),
             'reason' => __('Zentyal needs the directories to record pending slave actions.'),
             'module' => 'usercorner'
            });

    return \@actions;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Execute initial-setup script
    $self->SUPER::initialSetup($version);

    my $haproxyMod = $self->global()->modInstance('haproxy');

    # Register the service if installing the first time
    unless ($version) {
        my @args = ();
        push (@args, modName        => $self->name);
        push (@args, sslPort        => $self->defaultHTTPSPort());
        push (@args, enableSSLPort  => 1);
        push (@args, defaultSSLPort => 1);
        push (@args, force          => 1);
        $haproxyMod->setHAProxyServicePorts(@args);
        $haproxyMod->saveConfigRecursive();
    }

    # Upgrade from 3.3
    if (defined ($version) and (EBox::Util::Version::compare($version, '3.4') < 0)) {
        $self->_migrateTo34();
    }

    if ($haproxyMod->changed()) {
        $haproxyMod->saveConfigRecursive();
    }

    if ($self->changed()) {
       $self->saveConfigRecursive();
    }

    my $fwMod = $self->global()->modInstance('firewall');
    if ($fwMod and $fwMod->changed()){
        $fwMod->saveConfigRecursive();
    }
}

# Migration to 3.4
#
#  * Migrate redis keys to use haproxy.
#
sub _migrateTo34
{
    my ($self) = @_;

    my $haproxyMod = $self->global()->modInstance('haproxy');
    my $redis = $self->redis();
    my $key = 'usercorner/conf/Settings/keys/form';
    my $value = $redis->get($key);
    unless ($value) {
        # Fallback to the 'ro' version.
        $key = 'usercorner/ro/Settings/keys/form';
        $value = $redis->get($key);
    }
    if ($value) {
        if (defined $value->{port}) {
            # There are keys to migrate...
            my @args = ();
            push (@args, modName        => $self->name);
            push (@args, sslPort        => $value->{port});
            push (@args, enableSSLPort  => 1);
            push (@args, defaultSSLPort => 1);
            push (@args, force          => 1);
            $haproxyMod->setHAProxyServicePorts(@args);
        }

        my @keysToRemove = ('usercorner/conf/Settings/keys/form', 'usercorner/ro/Settings/keys/form');
        $redis->unset(@keysToRemove);
    } else {
        # This case happens when there is no modification on WebAdmin
        my @args = ();
        push (@args, modName        => $self->name);
        push (@args, sslPort        => $self->defaultHTTPSPort());
        push (@args, enableSSLPort  => 1);
        push (@args, defaultSSLPort => 1);
        push (@args, force          => 1);
        $haproxyMod->setHAProxyServicePorts(@args);
    }

    # Migrate the existing zentyal ca definition to follow the new layout used by HAProxy.
    my @caKeys = $redis->_keys('ca/*/Certificates/keys/*');
    foreach my $key (@caKeys) {
        my $value = $redis->get($key);
        unless (ref $value eq 'HASH') {
            next;
        }
        if ($value->{serviceId} eq 'User Corner web server') {
            $value->{serviceId} = 'zentyal_' . $self->name();
            $value->{service} = $self->printableName();
            $redis->set($key, $value);
        }
    }
}

sub _setupRoLDAPAccess
{
    my ($self) = @_;

    # Copy ldapro password.
    my $ucUser = USERCORNER_USER;
    my $ucGroup = USERCORNER_GROUP;
    my $ldapUsersPasswdFile = EBox::Config::conf() . 'ldap_ro.passwd';
    EBox::Sudo::root(
        "cp $ldapUsersPasswdFile " . USERCORNER_LDAP_PASS,
        "chown $ucUser:$ucGroup  " . USERCORNER_LDAP_PASS,
        "chmod 600 " . USERCORNER_LDAP_PASS
    );
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;
    # check if users module is running in standalone mode
    my $users = $self->global()->modInstance('users');
    if ($users->mode() ne $users->STANDALONE_MODE) {
        throw EBox::Exceptions::External(__(
            'User corner needs that the users module is configured in standalone server mode'));
    }

    # Create userjournal dir if it not exists
    my @commands;
    my $ucUser = USERCORNER_USER;
    my $ucGroup = USERCORNER_GROUP;
    my $usercornerDir = EBox::UserCorner::journalDir();
    unless (-d $usercornerDir) {
        push (@commands, "mkdir -p $usercornerDir");
        push (@commands, "chown $ucUser:$ucGroup $usercornerDir");
        EBox::Sudo::root(@commands);
    }

    $self->_setupRoLDAPAccess();

    # migrate modules to usercorner
    (-d (EBox::Config::conf() . 'configured')) and return;

    my $names = EBox::Global->modNames();
    mkdir(EBox::Config::conf() . 'configured.tmp/');
    foreach my $name (@{$names}) {
        my $mod = EBox::Global->modInstance($name);
        my $class = 'EBox::Module::Service';
        if ($mod->isa($class) and $mod->configured()) {
            EBox::Sudo::command('touch ' . EBox::Config::conf() . 'configured.tmp/' . $mod->name());
        }
    }
    rename(EBox::Config::conf() . 'configured.tmp', EBox::Config::conf() . 'configured');
}

# Method: enableService
#
#   Override EBox::Module::Service::enableService
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    if ($self->changed()) {
        # manage the nginx include file
        my $webadminMod = $self->global()->modInstance('webadmin');
        if ($status) {
            $webadminMod->addNginxServer(USERCORNER_NGINX_FILE);
        } else {
            $webadminMod->removeNginxServer(USERCORNER_NGINX_FILE);
        }
    }
}

# Method: menu
#
# Show the usercorner menu entry
#
# Overrides:
#
# <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Users',
                                        'icon' => 'users',
                                        'text' => __('Users and Computers'),
                                        'separator' => 'Office',
                                        'order' => 510);

    my $item = new EBox::Menu::Item(text => $self->printableName(),
                                    url => 'Users/UserCorner',
                                    order => 100);
    $folder->add($item);
    $root->add($folder);
}

# Method: _daemons
#
#  Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            name => USERCORNER_UPSTART_NAME,
        },
        {
            name => 'ebox.redis-usercorner'
        }
    ];
}

# Method: _setConf
#
#  Override <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $permissions = {
        uid => 0,
        gid => 0,
        mode => '0644',
        force => 1,
    };
    my $socketPath = '/run/zentyal-' . $self->name();
    my $socketName = 'usercorner.sock';
    my $upstartFileTemplate = 'core/upstart-uwsgi.mas';
    my $upstartFile = '/etc/init/' . USERCORNER_UPSTART_NAME . '.conf';
    my @confFileParams = ();
    push (@confFileParams, socketpath => $socketPath);
    push (@confFileParams, socketname => $socketName);
    push (@confFileParams, script => EBox::Config::psgi() . 'usercorner.psgi');
    push (@confFileParams, module => $self->printableName());
    push (@confFileParams, user   => USERCORNER_USER);
    push (@confFileParams, group  => USERCORNER_GROUP);
    EBox::Module::Base::writeConfFileNoCheck(
        $upstartFile, $upstartFileTemplate, \@confFileParams, $permissions);

    my $nginxFileTemplate = 'usercorner/nginx.conf.mas';
    @confFileParams = ();
    push (@confFileParams, socket => "$socketPath/$socketName");
    push (@confFileParams, bindaddress => $self->targetIP());
    push (@confFileParams, port  => $self->targetHTTPSPort());
    EBox::Module::Base::writeConfFileNoCheck(
        USERCORNER_NGINX_FILE, $nginxFileTemplate, \@confFileParams, $permissions);

    # Write user corner redis file
    $self->{redis}->writeConfigFile(USERCORNER_USER);

    # As $users->editableMode() can't be called from usercorner, it will check
    # for the existence of this file
    my $editableFile = '/var/lib/zentyal-usercorner/editable';
    if (EBox::Global->modInstance('users')->editableMode()) {
        EBox::Sudo::root("touch $editableFile");
    } else {
        EBox::Sudo::root("rm -f $editableFile");
    }
}

sub certificates
{
    my ($self) = @_;

    return [
        {
            serviceId =>  'zentyal_' . $self->name(),
            service   =>  __(q{User Corner Web Server}),
            path      =>  $self->pathHTTPSSSLCertificate(),
            user      => USERCORNER_USER,
            group     => USERCORNER_GROUP,
            mode      => '0400',
        },
    ];
}

# Method: editableMode
#
#       Reimplementation of EBox::Users::editableMode()
#       compatible with user corner to workaround lack of redis access
#
#       Returns true if mode is editable
#
sub editableMode
{
    return (-f '/var/lib/zentyal-usercorner/editable');
}

# Method: roRootDn
#
#       Returns the dn of the read only priviliged user
#
# Returns:
#
#       string - the Dn
sub roRootDn
{
    my $ldap = EBox::Ldap->instance();

    return $ldap->roRootDn();
}

# Method: getRoPassword
#
#   Returns the password of the read only privileged user
#   used to connect to the LDAP directory with read only
#   permissions
#
# Returns:
#
#       string - password
#
sub getRoPassword
{
    open(PASSWD, USERCORNER_LDAP_PASS) or
        throw EBox::Exceptions::External('Could not get LDAP password');

    my $pwd = <PASSWD>;
    close(PASSWD);

    $pwd =~ s/[\n\r]//g;
    return $pwd;
}

# Method: userCredentials
#
#   Return a tuple of user, pass and userDN strings for the logged in user.
#
# Raises: <EBox::Exceptions::Internal> If there are no credentials available.
#
sub userCredentials
{
    my ($self) = @_;

    my $global = $self->global();
    my $request = $global->request();
    unless (defined $request) {
        throw EBox::Exceptions::Internal("There is no request available!");
    }
    my $session = $request->session();
    unless (defined $session->{user_id}) {
        throw EBox::Exceptions::Internal("There is no user_id information in the request object!");
    }
    my $user = $session->{user_id};
    unless (defined $session->{userDN}) {
        throw EBox::Exceptions::Internal("There is no userDN information in the request object!");
    }
    my $userDN = $session->{userDN};
    my $pass = EBox::UserCorner::Middleware::AuthLDAP->sessionPassword($request);
    unless (defined $pass) {
        throw EBox::Exceptions::Internal("There is password defined for this request object!");
    }

    return ($user, $pass, $userDN);
}

sub updateSessionPassword
{
    my ($self, $passwd) = @_;
    my $global = $self->global();
    EBox::UserCorner::Middleware::AuthLDAP->updateSessionPassword($global->request(), $passwd);
}

#
# Implementation of EBox::HAProxy::ServiceBase
#

# Method: allowServiceDisabling
#
#   Usercorner must be always on so users don't lose access to the admin UI.
#
# Returns:
#
#   boolean - Whether this service may be disabled from the reverse proxy.
#
sub allowServiceDisabling
{
    return 0;
}

# Method: defaultHTTPSPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service over SSL or undef if unused.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::defaultHTTPSPort>
#
sub defaultHTTPSPort
{
    return 8888;
}

# Method: blockHTTPPortChange
#
#   Always return True to prevent that user corner is served without SSL.
#
# Returns:
#
#   boolean - Whether the port may be customised or not.
#
sub blockHTTPPortChange
{
    return 1;
}

# Method: pathHTTPSSSLCertificate
#
# Returns:
#
#   string - The full path to the SSL certificate file to use by HAProxy.
#
sub pathHTTPSSSLCertificate
{
    return '/var/lib/zentyal-usercorner/ssl/ssl.pem';
}

# Method: targetIP
#
# Returns:
#
#   string - IP address where the service is listening, usually 127.0.0.1 .
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::targetIP>
#
sub targetIP
{
    return '127.0.0.1';
}

# Method: targetHTTPSPort
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetIP> where the service is listening for SSL requests.
#
# Overrides:
#
#   <EBox::HAProxy::ServiceBase::targetHTTPSPort>
#
sub targetHTTPSPort
{
    return 61888;
}

1;
