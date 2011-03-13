# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::UsersAndGroups;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::LdapModule
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::UserCorner::Provider
          );

use EBox::Global;
use EBox::Ldap;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo;
use EBox::FileSystem;
use EBox::LdapUserImplementation;
use EBox::Config;
use EBox::UsersAndGroups::Passwords;
use EBox::UsersAndGroups::Setup;
use EBox::SOAPClient;

use Digest::SHA1;
use Digest::MD5;
use Crypt::SmbHash;
use Sys::Hostname;

use Error qw(:try);
use File::Copy;
use File::Slurp;
use File::Temp qw/tempfile/;
use Perl6::Junction qw(any);
use String::ShellQuote;
use Fcntl qw(:flock);

use constant USERSDN        => 'ou=Users';
use constant GROUPSDN       => 'ou=Groups';
use constant MASTERDN       => 'cn=master';
use constant SLAVESDN       => 'ou=slaves';
use constant SYSMINUID      => 1900;
use constant SYSMINGID      => 1900;
use constant MINUID         => 2000;
use constant MINGID         => 2000;
use constant HOMEPATH       => '/home';
use constant MAXUSERLENGTH  => 128;
use constant MAXGROUPLENGTH => 128;
use constant MAXPWDLENGTH   => 512;
use constant LIBNSSLDAPFILE => '/etc/ldap.conf';
use constant SECRETFILE     => '/etc/ldap.secret';
use constant LDAPCONFDIR    => '/etc/ldap/';
use constant DEFAULTGROUP   => '__USERS__';
use constant CONFLDIF       => '/etc/ldap/eboxldap.ldif';
use constant CA_DIR         => EBox::Config::conf() . 'ssl-ca/';
use constant SSL_DIR        => EBox::Config::conf() . 'ssl/';
use constant CERT           => SSL_DIR . 'master.cert';
use constant AUTHCONFIGTMPL => '/etc/auth-client-config/profile.d/acc-ebox';
use constant LOCK_FILE      => EBox::Config::tmp() . 'ebox-users-lock';


sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'users',
                                      printableName => __n('Users and Groups'),
                                      domain => 'ebox-usersandgroups',
                                      @_);

    bless($self, $class);
    return $self;
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    my ($self) = @_;

    my $mode = mode();
    my @actions;

    if ($mode eq 'master') {
        push(@actions,
                {
                 'action' => __('Your LDAP database will be populated with some basic organizational units'),
                 'reason' => __('Zentyal needs this organizational units to add users and groups into them.'),
                 'module' => 'users'
                },
                {
                 'action' => __('Create directories for slave journals'),
                 'reason' => __('Zentyal needs the directories to record pending slave actions.'),
                 'module' => 'users'
                }
        );
    } elsif ($mode eq 'slave') {
        push(@actions,
                {
                 'action' => __('Your Zentyal will be registered as a slave in the Zentyal master specified'),
                 'reason' => __('This Zentyal needs to have remote access to the users in the Zentyal master.'),
                 'module' => 'users'
                }
        );
        if ( -f '/etc/init.d/apparmor' ) {
            push(@actions,
                    {
                     'action' => __('Apparmor profile will be disabled'),
                     'reason' => __('It is not ready to work with more than one slapd.'),
                     'module' => 'users'
                    }
            );
        }
    } elsif ($mode eq 'ad-slave') {
        push(@actions,
                {
                 'action' => __('Install /etc/cron.d/ebox-ad-sync.'),
                 'reason' => __('Zentyal will run a script every 5 minutes to sync with Windows AD.'),
                 'module' => 'users'
                }
        );

    }
    if ($self->model('PAM')->enable_pamValue()) {
        push(@actions,
                {
                 'action' => __('Configure PAM.'),
                 'reason' => __('Zentyal will give LDAP users system account.'),
                 'module' => 'users'
                }
        );
    }
    return \@actions;
}

# Method: usedFiles
#
#       Override EBox::Module::Service::files
#
sub usedFiles
{
    my @files = ();
    my $mode = mode();

    push(@files,
            {
             'file' => '/etc/nsswitch.conf',
             'reason' => __('To make NSS use LDAP resolution for user and group '.
                 'accounts. Needed for Samba PDC configuration.'),
             'module' => 'samba'
            },
            {
             'file' => LIBNSSLDAPFILE,
             'reason' => __('To let NSS know how to access LDAP accounts.'),
             'module' => 'samba'
            },
    );

    if ($mode ne 'slave') {
        push(@files,
                {
                 'file' => '/etc/default/slapd',
                 'reason' => __('To make LDAP listen on TCP and Unix sockets.'),
                 'module' => 'users'
                },
                {
                    'file' => SECRETFILE,
                    'reason' => __('To copy LDAP admin password generated by ' .
                        'Zentyal and allow other modules to access LDAP.'),
                    'module' => 'users'
                },
        );
    }

    return \@files;
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;
    my $share = EBox::Config::share();

    # Lock to operate in exclusive mode
    open(my $lock, '>', LOCK_FILE);
    flock($lock, LOCK_EX);

    return if ($self->{enabled});
    $self->{enabled} = 1;

    my $mode = mode();

    if ($mode eq 'slave') {
        $self->disableApparmorProfile('usr.sbin.slapd');

        EBox::Sudo::root("invoke-rc.d slapd stop");
        EBox::Sudo::root("cp $share/ebox-usersandgroups/slapd.default.no " .
            '/etc/default/slapd');

        $self->_setupSlaveLDAP();
    } elsif ($mode eq 'master' or $mode eq 'ad-slave') {
        my $password = remotePassword();

        EBox::UsersAndGroups::Setup::master($password);

        $self->performLDAPActions();
    } else {
        throw EBox::Exceptions::Internal(
            "Trying to enable users with unknown LDAP mode: $mode");
    }
    EBox::Sudo::root("$share/ebox-usersandgroups/ebox-usersandgroups-enable");

    # Release lock
    flock($lock, LOCK_UN);
    close($lock);
}


# Method: wizardPages
#
#   Override EBox::Module::Base::wizardPages
#
sub wizardPages
{
    my ($self) = @_;

    return [ '/UsersAndGroups/Wizard/Users' ];
}


# Method: _setConf
#
#       Override EBox::Module::Service::_setConf
#
sub _setConf
{
    my ($self) = @_;

    my $mode = mode();
    my $ldap = $self->ldap;
    EBox::Module::Base::writeFile(SECRETFILE, $ldap->getPassword(),
        { mode => '0600', uid => 0, gid => 0 });

    my $soapfile = EBox::Config::conf() . "/apache-soap-slave";
    if( ( $mode eq 'slave' ) and ( not -f $soapfile ) ) {
        $self->disableApparmorProfile('usr.sbin.slapd');
        my $apache = EBox::Global->modInstance('apache');
        EBox::Module::Base::writeConfFileNoCheck($soapfile,
            'usersandgroups/soap-slave.mas',
            [ 'cert' => CERT ]
        );
        $apache->addInclude($soapfile);
        $apache->save();
    }

    if ( $mode eq 'ad-slave' ) {
        EBox::Sudo::root("rm -f /etc/cron.d/ebox-ad-sync");
        if ($self->adsyncEnabled()) {
            my $cronFile = EBox::Config::share() . '/ebox-usersandgroups/ebox-ad-sync.cron';
            EBox::Sudo::root("install -m 0644 -o root -g root $cronFile /etc/cron.d/ebox-ad-sync");
        }
    }

    my @array = ();
    my $dn;
    if ( $mode eq 'slave' ) {
        my $enablePam = $self->model('PAM')->enable_pamValue();

        # Bind to translucent if PAM enabled, to frontend if not (necessary for samba)
        if ( $enablePam ) {
            push(@array, 'ldap' => 'ldap://127.0.0.1:1389');
        } else {
            push(@array, 'ldap' => 'ldap://127.0.0.1');
        }
        $dn = $self->model('Mode')->dnValue();
    } else {
        # master or ad-sync
        push(@array, 'ldap' => EBox::Ldap::LDAPI);
        $dn = $ldap->dn;
    }

    push(@array, 'basedc'    => $dn);
    push(@array, 'binddn'    => 'cn=ebox,' . $dn);
    push(@array, 'usersdn'   => USERSDN . ',' . $dn);
    push(@array, 'groupsdn'  => GROUPSDN . ',' . $dn);
    push(@array, 'computersdn' => 'ou=Computers,' . $dn);

    $self->writeConfFile(LIBNSSLDAPFILE, "usersandgroups/ldap.conf.mas",
            \@array);

    $self->_setupNSSPAM();
}

# Method: adsyncEnabled
#
#       Returns true if ad-sync is enabled in ad-slave mode.
#
sub adsyncEnabled
{
    my ($self) = @_;

    my $model = $self->model('ADSyncSettings');
    return $model->enableADsyncValue();
}


# Method: editableMode
#
#       Check if users and groups can be edited.
#
#       Returns true if mode is master or disabled ad-sync
#       Returns false if slave or enabled ad-sync
#
sub editableMode
{
    my ($self) = @_;

    my $mode = $self->mode();

    if ($mode eq 'master') {
        return 1;
    } elsif ($mode eq 'slave') {
        return 0;
    } elsif ($mode eq 'ad-slave') {
        return not $self->adsyncEnabled();
    }
}

# Method: _daemons
#
#       Override EBox::Module::Service::_daemons
#
sub _daemons
{
    my ($self) = @_;

    my $mode = mode();

    if ($mode eq 'master') {
        return [];
    } elsif ($mode eq 'slave') {
        return [
            { 'name' => 'ebox.slapd-replica' },
            { 'name' => 'ebox.slapd-translucent' },
            { 'name' => 'ebox.slapd-frontend' },
        ];
    } elsif ($mode eq 'ad-slave') {
        return [
                {
                  'name' => 'ebox.ad-pwdsync',
                  'precondition' => \&adsyncEnabled
                }
        ];
    }
}

# Method: _enforceServiceState
#
#       Override EBox::Module::Service::_enforceServiceState
#
sub _enforceServiceState
{
    my ($self) = @_;

    my $mode = mode();

    # FIXME: This method should not be overrided
    # the good way to do this would be to have
    # _preService and _postService methods in
    # EBox::Module::Service like the _preSetConf
    # and _postSetConf in EBox::Module::Base

    if ($mode ne 'slave') {
        $self->_loadCertificates();
    }

    $self->SUPER::_enforceServiceState();

    if ($mode eq 'slave') {
        my ($ldap, $dn) = $self->_connRemoteLDAP();
        $self->_getCertificates($ldap, $dn);
    }
}

sub _loadCertificates
{
    my ($self) = @_;
    my $ca;
    my $cert;

    my $ldapca;

    $cert = read_file(SSL_DIR . "ssl.cert");
    $ca = $cert;

    EBox::Sudo::root('chown -R ebox:ebox /etc/ldap/ssl');
    $ldapca = read_file("/etc/ldap/ssl/ssl.cert");
    EBox::Sudo::root('chown -R openldap:openldap /etc/ldap/ssl');

    my $dn = $self->masterDn();

    # delete old certs and add new ones
    try {
        $self->ldap->delete($dn);
    } otherwise {};

    my %args = ('attr' => [
        'objectClass' => 'masterHost',
        'masterCertificate' => $cert,
        'masterCACertificate' => $ca,
        'masterLDAPCACertificate' => $ldapca
    ]);
    $self->ldap->add($dn, \%args);
}

# Method: modelClasses
#
#       Override <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::UsersAndGroups::Model::Mode',
        'EBox::UsersAndGroups::Model::Users',
        'EBox::UsersAndGroups::Model::Groups',
        'EBox::UsersAndGroups::Model::Password',
        'EBox::UsersAndGroups::Model::Slaves',
        'EBox::UsersAndGroups::Model::PendingSync',
        'EBox::UsersAndGroups::Model::ForceSync',
        'EBox::UsersAndGroups::Model::LdapInfo',
        'EBox::UsersAndGroups::Model::PAM',
        'EBox::UsersAndGroups::Model::ADSyncSettings',
    ];
}

# Method: compositeClasses
#
#       Override <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::UsersAndGroups::Composite::Settings',
        'EBox::UsersAndGroups::Composite::SlaveInfo',
        'EBox::UsersAndGroups::Composite::UserTemplate',
    ];
}
# Method: groupsDn
#
#       Returns the dn where the groups are stored in the ldap directory
#       Accepts an optional parameter as base dn instead of getting it
#       from the local LDAP repository
#
# Returns:
#
#       string - dn
#
sub groupsDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->ldap->dn();
    }
    return GROUPSDN . "," . $dn;
}

# Method: masterDn
#
#       Returns the dn where the Zentyal master machine is stored in LDAP
#
# Returns:
#
#       string - dn
#
sub masterDn
{
    my ($self) = @_;
    return MASTERDN . "," . $self->ldap->dn;
}


# Method: slavesDn
#
#       Returns the dn where the Zentyal slave machiens are stored in LDAP
#
# Returns:
#
#       string - dn
#
sub slavesDn
{
    my ($self) = @_;
    return SLAVESDN . "," . $self->ldap->dn;
}

# Method: groupDn
#
#    Returns the dn for a given group. The group don't have to existst
#
#   Parameters:
#       group
#
#  Returns:
#     dn for the group
sub groupDn
{
    my ($self, $group) = @_;
    $group or throw EBox::Exceptions::MissingArgument('group');

    my $dn = "cn=$group," .  $self->groupsDn;
    return $dn;
}

# Method: usersDn
#
#       Returns the dn where the users are stored in the ldap directory.
#       Accepts an optional parameter as base dn instead of getting it
#       from the local LDAP repository
#
# Returns:
#
#       string - dn
#
sub usersDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->ldap->dn();
    }
    return USERSDN . "," . $dn;
}

# Method: userDn
#
#    Returns the dn for a given user. The user don't have to existst
#
#   Parameters:
#       user
#
#  Returns:
#     dn for the user
sub userDn
{
    my ($self, $user) = @_;
    $user or throw EBox::Exceptions::MissingArgument('user');

    my $dn = "uid=$user," .  $self->usersDn;
    return $dn;
}



# Method: userExists
#
#       Checks if a given user exists
#
# Parameters:
#
#       user - user name
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub userExists # (user)
{
    my ($self, $user) = @_;

    my %attrs = (
                 base => $self->usersDn,
                 filter => "(uid=$user)",
                 scope => 'one'
                );

    my $result = $self->ldap->search(\%attrs);

    return ($result->count > 0);
}


# Method: uidExists
#
#       Checks if a given uid exists
#
# Parameters:
#
#       uid - uid number to check
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub uidExists # (uid)
{
    my ($self, $uid) = @_;

    my %attrs = (
                 base => $self->usersDn,
                 filter => "(uidNumber=$uid)",
                 scope => 'one'
                );

    my $result = $self->ldap->search(\%attrs);

    return ($result->count > 0);
}

# Method: lastUid
#
#       Returns the last uid used.
#
# Parameters:
#
#       system - boolan: if true, it returns the last uid for system users,
#       otherwise the last uid for normal users
#
# Returns:
#
#       string - last uid
#
sub lastUid # (system)
{
    my ($self, $system) = @_;

    my %args = (
                base =>  $self->ldap->dn(),
                filter => '(objectclass=posixAccount)',
                scope => 'sub',
                attrs => ['uidNumber']
               );

    my $result = $self->ldap->search(\%args);

    my @users = $result->sorted('uidNumber');

    my $uid = -1;
    foreach my $user (@users) {
        my $curruid = $user->get_value('uidNumber');
        if ($system) {
            last if ($curruid >= MINUID);
        } else {
            next if ($curruid < MINUID);
        }
        if ( $curruid > $uid){
            $uid = $curruid;
        }
    }

    if ($system) {
        return ($uid < SYSMINUID ?  SYSMINUID : $uid);
    } else {
        return ($uid < MINUID ?  MINUID : $uid);
    }
}

# Method: startIfRequired
#
#       Starts the usersandgroups module, might be required by the enableActions
#       of some modules which depend on LDAP
#
sub startIfRequired
{
    my ($self) = @_;
    if (not $self->isRunning()) {
        $self->_startService();
    }
}

# Method: stopIfRequired
#
#       Stops the usersandgroups module, might be required by the enableActions
#       of some modules which depend on LDAP
#
sub stopIfRequired
{
    my ($self) = @_;
    if ($self->isRunning()) {
        $self->_stopService();
    }
}

# Method: restoreState
#
#       Restores the state of the slapd daemons, might be required by the
#       enableActions of some modules that depend on LDAP
#
sub restoreState
{
    my ($self) = @_;
    $self->_enforceServiceState();
}

# Method: configured
#
#    Overrides EBox::Module::Service::configured method. The normal method
#    calls usedFiles() and actions() and it might cause migrations to not work
#
sub configured
{
    my ($self) = @_;

    if (-d EBox::Config::conf() . "configured/") {
        return -f (EBox::Config::conf() . "configured/" . $self->name());
    }

    unless ($self->st_get_bool('_serviceConfigured')) {
        return undef;
    }

    return $self->st_get_bool('_serviceConfigured');
}

sub rewriteObjectClasses
{
    my ($self, $dn) = @_;

    my $ldap = EBox::Ldap::safeConnect('ldap://127.0.0.1:1389');
    EBox::Ldap::safeBind(
        $ldap, $self->ldap->rootDn(), remotePassword());

    my %attrs = (
            base   => $dn,
            filter => "(objectclass=*)",
            attrs  => [ 'objectClass'],
            scope  => 'base'
            );
    my $result = $ldap->search(%attrs);

    my $classes = [ $result->pop_entry()->get_value('objectClass') ];

    # delete old user data if it's there
    try {
        $self->ldap->delete($dn);
    } otherwise {};

    $self->ldap->modify($dn,
        { 'changes' => [ 'replace' => [ 'objectClass' => $classes ] ]} );
}

sub rewriteObjectClassesTree
{
    my ($self, $dn) = @_;
    my $ldap = EBox::Ldap::safeConnect('ldap://127.0.0.1:1389');
    EBox::Ldap::safeBind($ldap, $self->ldap->rootDn(), remotePassword());
    my %attrs = (
            base   => $dn,
            filter => "(objectclass=*)",
            attrs  => [ 'objectClass'],
            scope  => 'sub'
    );
    my $result = $ldap->search(%attrs);
    for my $entry ($result->entries()) {
        $self->rewriteObjectClasses($entry->dn());
    }
}

sub initUser
{
    my ($self, $user, $password) = @_;

    my $home = $self->userInfo($user)->{'homeDirectory'};
    if ($home and ($home ne '/dev/null') and (not -e $home)) {
        my @cmds;

        my $quser = shell_quote($user);
        my $qhome = shell_quote($home);
        my $group = DEFAULTGROUP;
        push(@cmds, "mkdir -p `dirname $qhome`");
        push(@cmds, "cp -dR --preserve=mode /etc/skel $qhome");
        push(@cmds, "chown -R $quser:$group $qhome");

        my $dir_umask = oct(EBox::Config::configkey('dir_umask'));
        my $perms = sprintf("%#o", 00777 &~ $dir_umask);
        push(@cmds, "chmod $perms $qhome");

        EBox::Sudo::root(@cmds);
    }

    # Tell modules depending on users and groups
    # a new new user is created
    my @mods = @{$self->_modsLdapUserBase()};

    foreach my $mod (@mods) {
        $mod->_addUser($user, $password);
    }
}

sub soapClient
{
    my ($self, $slave) = @_;

    my $hostname = $slave->{'hostname'};
    my $port = $slave->{'port'};

    my $client = EBox::SOAPClient->instance(
        name  => 'urn:EBox/Users',
        proxy => "https://$hostname:$port/slave",
        certs => {
            cert => SSL_DIR . 'ssl.pem',
            private => SSL_DIR . 'ssl.key'
        }
    );
    return $client;
}

sub soapRun
{
    my ($self, $slave, $method, $param, @params) = @_;

    my $journaldir = $self->_journalsDir . $slave->{'hostname'};
    unless (-d $journaldir) {
        EBox::Sudo::root('mkdir -p ' . $journaldir,
                         'chown -R ebox:ebox ' . $self->_journalsDir);
    }
    my $client = $self->soapClient($slave);

    try {
        $client->$method($param, @params);
    } otherwise {
        EBox::debug("Unable to perform operation $method with parameter $param on slave $slave->{'hostname'}");
        my ($fh, $filename) = tempfile("$method-XXXX", DIR => $journaldir);
        print $fh "$method\n";
        print $fh "$param\n";
        for my $p (@params) {
            print $fh "$p\n";
        }
        $fh->close();
        rename($filename, "$filename.pending");
    };
}

sub _journalsDir
{
    return EBox::Config::conf() . 'userjournal/';
}

sub _initUserSlaves
{
    my ($self, $user) = @_;

    for my $slave (@{$self->listSlaves()}) {
        $self->soapRun($slave, 'addUser', $user);
    }
}

sub _initGroupSlaves
{
    my ($self, $group) = @_;

    for my $slave (@{$self->listSlaves()}) {
        my $client = $self->soapClient($slave);
        $self->soapRun($slave, 'addGroup', $group);
    }
}

# Method: addUser
#
#       Adds a user
#
# Parameters:
#
#       user - hash ref containing: 'user'(user name), 'fullname', 'password',
#       'givenname', 'surname' and 'comment'
#       system - boolean: if true it adds the user as system user, otherwise as
#       normal user
#       uidNumber - user UID numberer (optional and named)
#       additionalPasswords -list with additional passwords (optional)
sub addUser # (user, system)
{
    my ($self, $user, $system, %params) = @_;

    if (length($user->{'user'}) > MAXUSERLENGTH) {
        throw EBox::Exceptions::External(
                                         __x("Username must not be longer than {maxuserlength} characters",
                           maxuserlength => MAXUSERLENGTH));
    }

    my @userPwAttrs = getpwnam($user->{'user'});
    if (@userPwAttrs) {
        throw EBox::Exceptions::External(
            __("Username already exists on the system")
        );
    }
    unless (_checkName($user->{'user'})) {
        throw EBox::Exceptions::InvalidData(
                                            'data' => __('user name'),
                                            'value' => $user->{'user'});
    }

    # Verify user exists
    if ($self->userExists($user->{'user'})) {
        throw EBox::Exceptions::DataExists('data' => __('user name'),
                                           'value' => $user->{'user'});
    }

    my $uid = exists $params{uidNumber} ?
        $params{uidNumber} :
            $self->_newUserUidNumber($system);
    $self->_checkUid($uid, $system);

    my $gid = $self->groupGid(DEFAULTGROUP);

    my $passwd = $user->{'password'};
    if (not $passwd and not $system) {
        # system user could not have passwords
        throw EBox::Exceptions::MissingArgument(__('Password'));
    }

    my @additionalPasswords = ();
    if ($passwd) {
        $self->_checkPwdLength($user->{'password'});

        if (not isHashed($passwd)) {
            $passwd =  defaultPasswordHash($passwd);
        }

        if (exists $params{additionalPasswords}) {
            @additionalPasswords = @{ $params{additionalPasswords} }
        } else {
            # build addtional passwords using not-hashed pasword
            if (isHashed($user->{password})) {
                throw EBox::Exceptions::Internal('The supplied user password is already hashed, you must supply an additional password list');
            }

            @additionalPasswords = @{ EBox::UsersAndGroups::Passwords::additionalPasswords($user->{'user'}, $user->{'password'}) };
        }
    }

    # If fullname is not specified we build it with
    # givenname and surname
    unless (defined $user->{'fullname'}) {
        $user->{'fullname'} = '';
        if ($user->{'givenname'}) {
            $user->{'fullname'} = $user->{'givenname'} . ' ';
        }
        $user->{'fullname'} .= $user->{'surname'};
    }

    my @attr =  (
        'cn'            => $user->{'fullname'},
        'uid'           => $user->{'user'},
        'sn'            => $user->{'surname'},
        'loginShell'    => $self->_loginShell(),
        'uidNumber'     => $uid,
        'gidNumber'     => $gid,
        'homeDirectory' => _homeDirectory($user->{'user'}),
        'userPassword'  => $passwd,
        'objectclass'   => ['inetOrgPerson', 'posixAccount', 'passwordHolder'],
        @additionalPasswords
    );

    my %args = ( attr => \@attr );

    my $dn = "uid=" . $user->{'user'} . "," . $self->usersDn;
    my $r = $self->ldap->add($dn, \%args);


    $self->_changeAttribute($dn, 'givenName', $user->{'givenname'});
    $self->_changeAttribute($dn, 'description', $user->{'comment'});
    unless ($system) {
        $self->initUser($user->{'user'}, $user->{'password'});
        $self->_initUserSlaves($user->{'user'}, $user->{'password'});
    }

    if ( -f '/etc/init.d/nscd' ) {
        try {
            EBox::Sudo::root('/etc/init.d/nscd reload');
        } otherwise {};
    }
}

sub _newUserUidNumber
{
    my ($self, $systemUser) = @_;

    my $uid;
    if ($systemUser) {
        $uid = $self->lastUid(1) + 1;
        if ($uid == MINUID) {
            throw EBox::Exceptions::Internal(
                __('Maximum number of system users reached'));
        }
    } else {
        $uid = $self->lastUid + 1;
    }

    return $uid;
}


sub _checkUid
{
    my ($self, $uid, $system) = @_;

    if ($uid < MINUID) {
        if (not $system) {
            throw EBox::Exceptions::External(
                                              __x('Incorrect UID {uid} for a user . UID must be equal or greater than {min}',
                                                  uid => $uid,
                                                  min => MINUID,
                                                 )
                                             );
        }

    }
    else {
        if ($system) {
            throw EBox::Exceptions::External(
                                              __x('Incorrect UID {uid} for a system user . UID must be lesser than {max}',
                                                  uid => $uid,
                                                  max => MINUID,
                                                 )
                                             );

        }
    }

}

sub _modifyUserPwd
{
    my ($self, $user, $passwd) = @_;

    $self->_checkPwdLength($passwd);
    my $hash = defaultPasswordHash($passwd);
    my $dn = "uid=" . $user . "," . $self->usersDn;

    my %args = (
                base => $self->usersDn,
                filter => "(uid=$user)",
                scope => 'one',
                attrs => ['*'],
               );

    my $result = $self->ldap->search(\%args);
    my $entry = $result->entry(0);

    #remove old passwords
    my $delattrs = [];
    foreach my $attr ($entry->attributes) {
        if ($attr =~ m/^ebox(.*)Password$/) {
            push(@{$delattrs}, $attr);
        }
    }
    if(@{$delattrs}) {
        $self->ldap->modify($dn, { 'delete' => $delattrs } );
    }

    #add new passwords
    my %attrs = (
        changes => [
            replace => [
                'userPassword' => $hash,
                @{EBox::UsersAndGroups::Passwords::additionalPasswords($user, $passwd)}
            ]
        ]
    );
    if(! $self->ldap->isObjectClass($dn, 'passwordHolder')) {
        push(@{$attrs{'changes'}}, 'add', ['objectclass' => 'passwordHolder']);
    }
    $self->ldap->modify($dn, \%attrs);
}

sub updateUser
{
    my ($self, $user, $password) = @_;

    # Tell modules depending on users and groups
    # a user  has been updated
    my @mods = @{$self->_modsLdapUserBase()};

    foreach my $mod (@mods){
        $mod->_modifyUser($user, $password);
    }
}

sub _updateUserSlaves
{
    my ($self, $user) = @_;

    for my $slave (@{$self->listSlaves()}) {
        my $client = $self->soapClient($slave);
        $self->soapRun($slave, 'modifyUser', $user);
    }
}

sub _delUserSlaves
{
    my ($self, $user) = @_;

    for my $slave (@{$self->listSlaves()}) {
        my $client = $self->soapClient($slave);
        $self->soapRun($slave, 'delUser', $user);
    }
}

# Method: modifyUser
#
#       Modifies  user's attributes
#
# Parameters:
#
#       user - hash ref containing: 'user' (user name), 'givenname', 'surname',
#       'password', and comment. The only mandatory parameter is 'user' the
#       other attribute parameters would be ignored if they are missing.
#
sub modifyUser # (\%user)
{
    my ($self, $user) = @_;

    $self->modifyUserLocal($user);
    $self->_updateUserSlaves($user->{'username'});
}

# Method: modifyUserLocal
#
#       Modifies user's attributes without trying to update the slaves
#
# Parameters:
#
#       user - hash ref containing: 'user' (user name), 'fullname', 'password',
#       and comment. The only mandatory parameter is 'user' the other attribute
#       parameters would be ignored if they are missing.
#
sub modifyUserLocal # (\%user)
{
    my ($self, $user) = @_;

    my $uid = $user->{'username'};
    my $dn = $self->userDn($uid);

    # Verify user exists
    unless ($self->userExists($user->{'username'})) {
        throw EBox::Exceptions::DataNotFound('data'  => __('user name'),
                                             'value' => $uid);
    }

    foreach my $field (keys %{$user}) {
        if ($field eq 'comment') {
            $self->_changeAttribute($dn, 'description',
                                    $user->{'comment'});
        } elsif ($field eq 'givenname') {
            $self->_changeAttribute($dn, 'givenName', $user->{'givenname'});
        } elsif ($field eq 'surname') {
            $self->_changeAttribute($dn, 'sn', $user->{'surname'});
        } elsif ($field eq 'fullname') {
            $self->_changeAttribute($dn, 'cn', $user->{'fullname'});
        } elsif ($field eq 'password') {
            my $pass = $user->{'password'};
            $self->_modifyUserPwd($user->{'username'}, $pass);
        }
    }
    $self->updateUser($uid, $user->{'password'});
}

# Clean user stuff when deleting a user
sub _cleanUser
{
    my ($self, $user) = @_;

    my @mods = @{$self->_modsLdapUserBase()};

    # Tell modules depending on users and groups
    # an user is to be deleted
    foreach my $mod (@mods) {
        $mod->_delUser($user);
    }
}

# Method: delUser
#
#       Removes a given user
#
# Parameters:
#
#       user - user name to be deleted
#
sub delUser # (user)
{
    my ($self, $user) = @_;

    # Verify user exists
    unless ($self->userExists($user)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $user);
    }

    $self->_cleanUser($user);
    # Delete user from groups
    foreach my $group (@{$self->groupsOfUser($user)}) {
        $self->delUserFromGroup($user, $group);
    }

    # Remove data added by modules
    $self->_delUserSlaves($user);

    # Delete user
    my $r = $self->ldap->delete("uid=" . $user . "," . $self->usersDn);
}

# Method: delUserSlave
#
#       Removes a given user in a slave
#
# Parameters:
#
#       user - user name to be deleted
#
sub delUserSlave # (user)
{
    my ($self, $user) = @_;

    $self->_cleanUser($user);
}

# Method: userInfo
#
#       Returns a hash ref containing the inforamtion for a given user
#
# Parameters:
#
#       user - user name to gather information
#       entry - *optional* ldap entry for the user
#
# Returns:
#
#       hash ref - holding the keys: 'username', 'givenname', 'surname', 'fullname'
#      password', 'homeDirectory', 'uid' and 'group'
#
sub userInfo # (user, entry)
{
    my ($self, $user, $entry) = @_;

    # Verify user  exists
    unless ($self->userExists($user)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $user);
    }

    # If $entry is undef we make a search to get the object, otherwise
    # we already have the entry
    unless ($entry) {
        my %args = (
                    base => $self->usersDn,
                    filter => "(uid=$user)",
                    scope => 'one',
                    attrs => ['*'],
                   );

        my $result = $self->ldap->search(\%args);
        $entry = $result->entry(0);
    }

    # Mandatory data
    my $userinfo = {
                    username => $entry->get_value('uid'),
                    fullname => $entry->get_value('cn'),
                    surname => $entry->get_value('sn'),
                    password => $entry->get_value('userPassword'),
                    homeDirectory => $entry->get_value('homeDirectory'),
                    uid => $entry->get_value('uidNumber'),
                    group => $entry->get_value('gidNumber'),
                    extra_passwords => {}
                   };

    foreach my $attr ($entry->attributes) {
        if ($attr =~ m/^ebox(.*)Password$/) {
            my $format = lc($1);
            $userinfo->{extra_passwords}->{$format} = $entry->get_value($attr);
        }
    }

    # Optional Data
    my $givenName = $entry->get_value('givenName');
    if ($givenName) {
        $userinfo->{'givenname'} = $givenName;
    } else {
        $userinfo->{'givenname'} = '';
    }
    my $desc = $entry->get_value('description');
    if ($desc) {
        $userinfo->{'comment'} = $desc;
    } else {
        $userinfo->{'comment'} = '';
    }

    return $userinfo;
}

# Method: uidList
#
#       Returns an ordered array containing all uid
#
# Returns:
#
#       array - holding the uid
#
sub uidList
{
    my ($self, $system) = @_;

    my %args = (
                base => $self->usersDn,
                filter => 'objectclass=*',
                scope => 'one',
                attrs => ['uid', 'uidNumber']
               );

    my $result = $self->ldap->search(\%args);

    my @users = ();
    foreach my $user ($result->sorted('uid'))
        {
            if (not $system) {
                next if ($user->get_value('uidNumber') < MINUID);
            }
            push (@users, $user->get_value('uid'));
        }

    return \@users;
}

# Method: users
#
#       Returns an array containing all the users (not system users)
#
# Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the users. Each user is represented by a hash reference
#       with the same format than the return value of userInfo
#
sub users
{
    my ($self, $system) = @_;

    my %args = (
                base => $self->usersDn,
                filter => 'objectclass=*',
                scope => 'one',
                attrs => ['uid', 'cn', 'givenName', 'sn', 'homeDirectory',
                          'userPassword', 'uidNumber', 'gidNumber',
                          'description']
               );

    my $result = $self->ldap->search(\%args);

    my @users = ();
    foreach my $user ($result->sorted('uid'))
        {
            if (not $system) {
                next if ($user->get_value('uidNumber') < MINUID);
            }

            @users = (@users,  $self->userInfo($user->get_value('uid'),
                                               $user))
        }

    return @users;
}

# Method: usersList
#
#       Returns an array containing all the users (not system users)
#
# Returns:
#
#       array ref - containing hash refs with the following keys
#
#            user => user name
#            uid => uid number
#
sub usersList
{
    my ($self) = @_;

    my %args = (
                base => $self->usersDn,
                filter => 'objectclass=*',
                scope => 'one',
                attrs => ['uid', 'uidNumber']
               );

    my $result = $self->ldap->search(\%args);

    my @users = ();
    foreach my $user ($result->sorted('uid'))
        {
            next if ($user->get_value('uidNumber') < MINUID);
            push (@users,  { user => $user->get_value('uid'),
                    uid => $user->get_value('uidNumber') });
        }

    return \@users;
}


# Method: groupExists
#
#       Checks if a given group name exists
#
# Parameters:
#
#       group - group name
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub groupExists # (group)
{
    my ($self, $group) = @_;

    my %attrs = (
                 base => $self->groupsDn,
                 filter => "(cn=$group)",
                 scope => 'one'
                );

    my $result = $self->ldap->search(\%attrs);

    return ($result->count > 0);
}

# Method: gidExists
#
#       Checks if a given gid number exists
#
# Parameters:
#
#       gid - gid number
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub gidExists
{
    my ($self, $gid) = @_;

    my %attrs = (
                 base => $self->groupsDn,
                 filter => "(gidNumber=$gid)",
                 scope => 'one'
                );

    my $result = $self->ldap->search(\%attrs);

    return ($result->count > 0);
}

# Method: lastGid
#
#       Returns the last gid used.
#
# Parameters:
#
#       system - boolan: if true, it returns the last gid for system users,
#       otherwise the last gid for normal users
#
# Returns:
#
#       string - last gid
#
sub lastGid # (gid)
{
    my ($self, $system) = @_;

    my %args = (
                base => $self->groupsDn,
                filter => '(objectclass=posixGroup)',
                scope => 'one',
                attrs => ['gidNumber']
               );

    my $result = $self->ldap->search(\%args);

    my @users = $result->sorted('gidNumber');

    my $gid = -1;
    foreach my $user (@users) {
        my $currgid = $user->get_value('gidNumber');
        if ($system) {
                        last if ($currgid > MINGID);
                    } else {
                        next if ($currgid < MINGID);
                    }

        if ( $currgid > $gid){
            $gid = $currgid;
        }
    }

    if ($system) {
        return ($gid < SYSMINUID ?  SYSMINUID : $gid);
    } else {
        return ($gid < MINUID ?  MINUID : $gid);
    }

}

# Method: addGroup
#
#       Adds a new group
#
# Parameters:
#
#       group - group name
#       comment - comment's group
#       system - boolan: if true it adds the group as system group,
#       otherwise as normal group
#
sub addGroup # (group, comment, system)
{
    my ($self, $group, $comment, $system, %params) = @_;

    if (length($group) > MAXGROUPLENGTH) {
        throw EBox::Exceptions::External(
                        __x("Groupname must not be longer than {maxGroupLength} characters",
                            maxGroupLength => MAXGROUPLENGTH));
    }

    if (($group eq DEFAULTGROUP) and (not $system)) {
        throw EBox::Exceptions::External(
                        __('The group name is not valid because it is used' .
                           ' internally'));
        }

    unless (_checkName($group)) {
        throw EBox::Exceptions::InvalidData(
                                            'data' => __('group name'),
                                            'value' => $group);
        }
    # Verify group exists
    if ($self->groupExists($group)) {
        throw EBox::Exceptions::DataExists('data' => __('group name'),
                                           'value' => $group);
    }
    #FIXME
    my $gid = exists $params{gidNumber} ?
        $params{gidNumber} :
            $self->_gidForNewGroup($system);

    $self->_checkGid($gid, $system);

    my %args = (
                attr => [
                         'cn'        => $group,
                         'gidNumber'   => $gid,
                         'objectclass' => ['posixGroup']
                            ]
               );

    my $dn = "cn=" . $group ."," . $self->groupsDn;
    my $r = $self->ldap->add($dn, \%args);


    $self->_changeAttribute($dn, 'description', $comment);

    unless ($system) {
        $self->initGroup($group);
        $self->_initGroupSlaves($group);
    }

    if ( -f '/etc/init.d/nscd' ) {
        try {
            EBox::Sudo::root('/etc/init.d/nscd reload');
        } otherwise {};
    }

}

sub initGroup
{
    my ($self, $group) = @_;

    # Tell modules depending on users and groups
    # a new group is created
    my @mods = @{$self->_modsLdapUserBase()};

    foreach my $mod (@mods){
        $mod->_addGroup($group);
    }
}

sub _gidForNewGroup
{
    my ($self, $system) = @_;

    my $gid;
    if ($system) {
        $gid = $self->lastGid(1) + 1;
        if ($gid == MINGID) {
            throw EBox::Exceptions::Internal(
                                __('Maximum number of system users reached'));
        }
    } else {
        $gid = $self->lastGid + 1;
    }

    return $gid;
}


sub _checkGid
{
    my ($self, $gid, $system) = @_;

    if ($gid < MINGID) {
        if (not $system) {
            throw EBox::Exceptions::External(
                                              __x('Incorrect GID {gid} for a group . GID must be equal or greater than {min}',
                                                  gid => $gid,
                                                  min => MINGID,
                                                 )
                                             );
        }
    }
    else {
        if ($system) {
            throw EBox::Exceptions::External(
                                              __x('Incorrect GID {gid} for a system group . GID must be lesser than {max}',
                                                  gid => $gid,
                                                  max => MINGID,
                                                 )
                                             );

        }
    }

}



sub updateGroup
{
    my ($self, $group, @params) = @_;

    $self->updateGroupLocal($group, @params);
    if (mode() ne 'slave') {
        $self->_updateGroupSlaves($group, @params);
    }
}

sub updateGroupLocal
{
    my ($self, $group, @params) = @_;

    # Tell modules depending on groups and groups
    # a group  has been updated
    my @mods = @{$self->_modsLdapUserBase()};

    foreach my $mod (@mods){
        $mod->_modifyGroup($group, @params);
    }
}

sub _updateGroupSlaves
{
    my ($self, $group, @params) = @_;

    for my $slave (@{$self->listSlaves()}) {
        my $client = $self->soapClient($slave);
        $self->soapRun($slave, 'updateGroup', $group, @params);
    }
}

sub _delGroupSlaves
{
    my ($self, $group) = @_;

    for my $slave (@{$self->listSlaves()}) {
        my $client = $self->soapClient($slave);
        $self->soapRun($slave, 'delGroup', $group);
    }
}

# Method: modifyGroup
#
#       Modifies a group
#
# Parameters:
#
#       hash ref - holding the keys 'groupname' and 'comment'. At the moment
#       comment is the only modifiable attribute
#
sub modifyGroup # (\%groupdata))
{
    my ($self, $groupdata, @params) = @_;

    my $cn = $groupdata->{'groupname'};
    my $dn = "cn=$cn," . $self->groupsDn;
    # Verify group  exists
    unless ($self->groupExists($cn)) {
        throw EBox::Exceptions::DataNotFound('data'  => __('user name'),
                                             'value' => $cn);
    }

    $self->_changeAttribute($dn, 'description', $groupdata->{'comment'});
}

# Clean group stuff when deleting a user
sub _cleanGroup
{
    my ($self, $group) = @_;

    my @mods = @{$self->_modsLdapUserBase()};

    # Tell modules depending on users and groups
    # a group is to be deleted
    foreach my $mod (@mods){
        $mod->_delGroup($group);
    }
}

# Method: delGroup
#
#       Removes a given group
#
# Parameters:
#
#       group - group name to be deleted
#
sub delGroup # (group)
{
    my ($self, $group) = @_;

    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                            'value' => $group);
    }

        $self->_cleanGroup($group);
        my $dn = "cn=" . $group . "," . $self->groupsDn;
        my $result = $self->ldap->delete($dn);

    $self->_delGroupSlaves($group);
}

# Method: delGroupSlave
#
#       Removes a given group in a slave
#
# Parameters:
#
#       group - group name to be deleted
#
sub delGroupSlave # (group)
{
    my ($self, $group) = @_;

    $self->_cleanGroup($group);
}

# Method: groupInfo
#
#       Returns a hash ref containing the inforamtion for a given group
#
# Parameters:
#
#       group - group name to gather information
#       entry - *optional* ldap entry for the group
#
# Returns:
#
#       hash ref - holding the keys: 'groupname', 'comment' and 'gid'
sub groupInfo # (group)
{
    my ($self, $group) = @_;

    # Verify user don't exists
    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $group);
    }

    my %args = (
                base => $self->groupsDn,
                filter => "(cn=$group)",
                scope => 'one',
                attrs => ['cn', 'gidNumber', 'description']
               );

    my $result = $self->ldap->search(\%args);

    my $entry = $result->entry(0);
    # Mandatory data
    my $groupinfo = {
                     groupname => $entry->get_value('cn'),
                     gid => $entry->get_value('gidNumber'),
                    };


    my $desc = $entry->get_value('description');
    if ($desc) {
        $groupinfo->{'comment'} = $desc;
    } else {
        $groupinfo->{'comment'} = "";
    }

    return $groupinfo;

}

# Method: groups
#
#       Returns an array containing all the groups
#
#   Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the groups
#
# Warning:
#
#   the group hashes are NOT the sames that we get from groupInfo, the keys are:
#     account(group name), desc (description) and gid
sub groups
{
    my ($self, $system) = @_;
    defined $system or $system = 0;

    my %args = (
                base => $self->groupsDn,
                filter => '(objectclass=*)',
                scope => 'one',
                attrs => ['cn', 'gidNumber', 'description']
               );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach ($result->sorted('cn')) {
        if (not $system) {
            next if ($_->get_value('gidNumber') < MINGID);
        }


        my $info = {
                    'account' => $_->get_value('cn'),
                    'gid' => $_->get_value('gidNumber'),
                   };

        my $desc = $_->get_value('description');
        if ($desc) {
            $info->{'desc'} = $desc;
        }

        push @groups, $info;
    }

    return @groups;
}

# Method: addUserToGroup
#
#       Adds a user to a given group
#
# Parameters:
#
#       user - user name to add to the group
#       group - group name
#
# Exceptions:
#
#       DataNorFound - If user or group don't exist
sub addUserToGroup # (user, group)
{
    my ($self, $user, $group) = @_;

    unless ($self->userExists($user)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $user);
    }

    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                             'value' => $group);
    }

    my $dn = "cn=" . $group . "," . $self->groupsDn;

    my %attrs = ( add => { memberUid => $user } );
    $self->ldap->modify($dn, \%attrs);

    $self->updateGroup($group, op => 'add', user => $user);
}

# Method: delUserFromGroup
#
#       Removes a user from a group
#
# Parameters:
#
#       user - user name to remove  from the group
#       group - group name
#
# Exceptions:
#
#       DataNorFound - If user or group don't exist
sub delUserFromGroup # (user, group)
{
    my ($self, $user, $group) = @_;

    unless ($self->userExists($user)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $user);
    }

    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFoud('data' => __('group name'),
                                            'value' => $group);
    }

    my $dn = "cn=" . $group . "," . $self->groupsDn;
    my %attrs = ( delete => {  memberUid => $user  } );
        $self->ldap->modify($dn, \%attrs);

    $self->updateGroup($group, op => 'del', user => $user);
}

# Method: groupsOfUser
#
#       Given a user it returns all the groups which the user belongs to
#
# Parameters:
#
#       user   - user name
#       system - show system groups (default: false) *optional*
#
# Returns:
#
#       array ref - holding the groups
#
# Exceptions:
#
#       DataNotFound - If user does not exist
#
sub groupsOfUser # (user, system?)
{
    my ($self, $user, $system) = @_;
    defined $system or $system = 0;

    return $self->_ldapSearchUserGroups($user, $system, 0);
}

# Method: groupsNotOfUser
#
#       Given a user it returns all the groups which the user doesn't belong to
#
# Parameters:
#
#       user   - user name
#       system - show system groups (default: false) *optional*
#
# Returns:
#
#       array ref - holding the groups
#
# Exceptions:
#
#       DataNotFound - If user does not  exist
#
sub groupsNotOfUser # (user, system?)
{
    my ($self, $user, $system) = @_;
    defined $system or $system = 0;

    return $self->_ldapSearchUserGroups($user, $system, 1);
}

sub _ldapSearchUserGroups # (user, system, inverse)
{
    my ($self, $user, $system, $inverse) = @_;

    unless ($self->userExists($user)) {
        throw EBox::Exceptions::DataNotFound('data' => __('user name'),
                                             'value' => $user);
    }

    my $filter = '&(objectClass=*)';
    if ($inverse) {
        $filter .= "(!(memberUid=$user))"
    } else {
        $filter .= "(memberUid=$user)";
    }

    my %attrs = (
                 base => $self->groupsDn,
                 filter => $filter,
                 scope => 'one',
                 attrs => ['cn', 'gidNumber']
                );

    my $result = $self->ldap->search(\%attrs);

    my @groups;
    foreach my $entry ($result->entries) {
        if (not $system) {
            next if ($entry->get_value('gidNumber') < MINGID);
        }
        push @groups, $entry->get_value('cn');
    }

    return \@groups;
}

# Method: usersInGroup
#
#       Given a group it returns all the users belonging to it
#
# Parameters:
#
#       group - group name
#
# Returns:
#
#       array ref - holding the users
#
# Exceptions:
#
#       DataNorFound - If group does not  exist
sub usersInGroup # (group)
{
    my ($self, $group) = @_;

    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                             'value' => $group);
    }

    my %attrs = (
                 base => $self->groupsDn,
                 filter => "(cn=$group)",
                 scope => 'one',
                 attrs => ['memberUid']
                );

    my $result = $self->ldap->search(\%attrs);

    my @users;
    foreach my $res ($result->sorted('memberUid')){
                push @users, $res->get_value('memberUid');
            }

    return \@users;

}

# Method: usersNotInGroup
#
#       Given a group it returns all the users who not belonging to it
#
# Parameters:
#
#       group - group name
#
# Returns:
#
#       array  - holding the groups
#
sub usersNotInGroup # (group)
{
    my ($self, $groupname) = @_;

    my $grpusers = $self->usersInGroup($groupname);
    my @allusers = $self->users();

    my @users;
    foreach my $user (@allusers){
        my $uid = $user->{username};
        unless (grep (/^$uid$/, @{$grpusers})){
            push @users, $uid;
        }
    }

    return @users;
}


# Method: gidGroup
#
#       Given a gid number it returns its group name
#
# Parameters:
#
#       gid - gid number
#
# Returns:
#
#       string - group name
#
sub gidGroup # (gid)
{
    my ($self, $gid) = @_;

    my %attrs = (
                 base => $self->groupsDn,
                 filter => "(gidNumber=$gid)",
                 scope => 'one',
                 attr => ['cn']
                );

    my $result = $self->ldap->search(\%attrs);

    if ($result->count == 0){
        throw EBox::Exceptions::DataNotFound(
                                             'data' => "Gid", 'value' => $gid);
    }

    return $result->entry(0)->get_value('cn');
}

# Method: groupGid
#
#       Given a group name  it returns its gid number
#
# Parameters:
#
#       group - group name
#
# Returns:
#
#       string - gid number
#
sub groupGid # (group)
{
    my ($self, $group) = @_;

    unless ($self->groupExists($group)) {
        throw EBox::Exceptions::DataNotFound('data' => __('group name'),
                                             'value' => $group);
    }

    my %attrs = (
                 base => $self->groupsDn,
                 filter => "(cn=$group)",
                 scope => 'one',
                 attr => ['cn']
                );

    my $result = $self->ldap->search(\%attrs);

    return $result->entry(0)->get_value('gidNumber');
}

sub _groupIsEmpty
{
    my ($self, $group) = @_;

    my @users = @{$self->usersInGroup($group)};

    return @users ? undef : 1;
}

sub _changeAttribute
{
    my ($self, $dn, $attr, $value) = @_;

    unless ($value and length($value) > 0){
        $value = undef;
    }
    my %args = (
            base => $dn,
            filter => 'objectclass=*',
            scope =>  'base'
            );

    my $result = $self->ldap->search(\%args);

    my $entry = $result->pop_entry();
    my $oldvalue = $entry->get_value($attr);

    # There is no value
    return if ( (not $value) and (not $oldvalue));

    # There is no change
    return if (($oldvalue and $value) and $oldvalue eq $value);

    if (($oldvalue and $value) and $value ne $oldvalue) {
        $entry->replace($attr => $value);
    } elsif ((not $value) and $oldvalue) {
        $entry->delete($attr);
    } elsif (($value) and (not $oldvalue)) {
        $entry->add($attr => $value);
    }

    $entry->update($self->ldap->ldapCon);
}

sub isHashed
{
    my ($pwd) = @_;
    return ($pwd =~ /^\{[0-9A-Z]+\}/);
}

sub _checkPwdLength
{
    my ($self, $pwd) = @_;

    if (isHashed($pwd)) {
        return;
    }

    if (length($pwd) > MAXPWDLENGTH) {
        throw EBox::Exceptions::External(
            __x("Password must not be longer than {maxPwdLength} characters",
            maxPwdLength => MAXPWDLENGTH));
    }
}

sub _checkName
{
    my ($name) = @_;

    if ($name =~ /^([a-zA-Z\d\s_-]+\.)*[a-zA-Z\d\s_-]+$/) {
        return 1;
    } else {
        return undef;
    }
}

# Returns modules implementing LDAP user base interface
sub _modsLdapUserBase
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
         my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::LdapModule')) {
            if ($mod->isa('EBox::Module::Service')) {
                if ($name ne $self->name()) {
                    $mod->configured() or
                        next;
                }
            }
            push (@modules, $mod->_ldapModImplementation);
        }
    }

    return \@modules;
}

# Method: defaultUserModels
#
#   Returns all the defaultUserModels from modules implementing
#   <EBox::LdapUserBase>
sub defaultUserModels
{
    my ($self) = @_;
    my @models;
    for my $module  (@{$self->_modsLdapUserBase()}) {
        my $model = $module->defaultUserModel();
        push (@models, $model) if (defined($model));
    }
    return \@models;
}

# Method: allUserAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _userAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       user - username
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allUserAddOns # (user)
{
    my ($self, $username) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        my $comp = $mod->_userAddOns($username);
        if ($comp) {
            push (@components, $comp);
        }
    }

    return \@components;
}

# Method: allGroupAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _groupAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       group  - group name
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allGroupAddOns
{
    my ($self, $groupname) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        my $comp = $mod->_groupAddOns($groupname);
        push (@components, $comp) if ($comp);
    }

    return \@components;
}

# Method: allLDAPLocalAttributes
#
#       Returns all the ldap local attributes requested by those modules
#       implementing the function _localAttributes from EBox::LdapUserBase
#
# Returns:
#
#       array ref - holding all the attributes
#
sub allLDAPLocalAttributes
{
    my ($self) = @_;

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @allAttributes;
    foreach my $mod (@modsFunc) {
        push (@allAttributes, @{$mod->_localAttributes()});
    }

    return \@allAttributes;
}

# Method: allWarning
#
#       Returns all the the warnings provided by the modules when a certain
#       user or group is going to be deleted. Function _delUserWarning or
#       _delGroupWarning is called in all module implementing them.
#
# Parameters:
#
#       object - Sort of object: 'user' or 'group'
#       name - name of the user or group
#
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings
{
    my ($self, $object, $name) = @_;

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @allWarns;
    foreach my $mod (@modsFunc) {
        my $warn = undef;
        if ($object eq 'user') {
            $warn = $mod->_delUserWarning($name);
        } else {
            $warn = $mod->_delGroupWarning($name);
        }
                push (@allWarns, $warn) if ($warn);
    }

    return \@allWarns;
}

# Method: isRunning
#
#       Overrides EBox::ServiceModule::ServiceInterface method.
#
sub isRunning
{
    my ($self) = @_;

    if (mode() eq 'master') {
        return $self->isEnabled();
    } else {
        return $self->SUPER::isRunning();
    }
}

# Method: _supportActions
#
#       Overrides EBox::ServiceModule::ServiceInterface method.
#
sub _supportActions
{
    return undef;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'UsersAndGroups',
                                        'text' => $self->printableName(),
                                        'separator' => 'Office',
                                        'order' => 510);

    if ($self->configured()) {
        my $model = EBox::Model::ModelManager->instance()->model('Mode');
        my $mode = $model->modeValue();

        if ($self->editableMode()) {
            $folder->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Users',
                                              'text' => __('Users')));
            $folder->add(new EBox::Menu::Item('url' => 'UsersAndGroups/Groups',
                                              'text' => __('Groups')));
            $folder->add(new EBox::Menu::Item('url' => 'Users/Composite/UserTemplate',
                                              'text' => __('User Template')));
        } else {
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/Users',
                        'text' => __('Users')));
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/Groups',
                        'text' => __('Groups')));
            $folder->add(new EBox::Menu::Item('url' => 'Users/Composite/UserTemplate',
                                              'text' => __('User Template')));
        }

        $folder->add(new EBox::Menu::Item(
                    'url' => 'Users/Composite/Settings',
                    'text' => __('LDAP Settings')));

        if ($mode eq 'master' or $mode eq 'ad-slave') {
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/Composite/SlaveInfo',
                        'text' => __('Slave Status')));
        }
        if ($mode eq 'ad-slave') {
            $folder->add(new EBox::Menu::Item(
                        'url' => 'Users/View/ADSyncSettings',
                        'text' => __('AD Sync Settings')));
        }

        $root->add($folder);
    } else {
        $folder->add(new EBox::Menu::Item('url' => 'Users/View/Mode',
                                          'text' => __('Mode')));
        $root->add($folder);
    }
}

# EBox::UserCorner::Provider implementation

# Method: userMenu
#
sub userMenu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => '/Users/View/Password',
                                      'text' => __('Password')));
}

# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::LdapUserImplementation();
}

sub dumpConfig
{
    my ($self, $dir, %options) = @_;

    my $mode = mode();

    if ($mode eq 'master' or $mode eq 'ad-slave') {
        $self->ldap->dumpLdapMaster($dir);
        if ($options{bug}) {
            my $file = $self->ldap->ldifFile($dir, 'master', 'data');
            $self->_removePasswds($file);
        }
    } elsif ($mode eq 'slave') {
        $self->ldap->dumpLdapReplica($dir);
        $self->ldap->dumpLdapTranslucent($dir);
        $self->ldap->dumpLdapFrontend($dir);
    } else {
        throw EBox::Exceptions::Internal(
            "Trying to dump configuration of unknown LDAP mode: $mode");
    }
}

sub _modeToBeRestored
{
    my ($self, $dir) = @_;

    my $masterFile = $self->ldap()->ldifFile($dir, 'master', 'data');
    if (-r $masterFile ) {
        # master or ad-slave is the same
        return 'master';
    } else {
        return 'slave';
    }
}

sub _usersInEtcPasswd
{
    my ($self) = @_;
    my @users;

    my @lines = File::Slurp::read_file('/etc/passwd');
    foreach my $line (@lines) {
        my ($user) = split ':', $line, 2;
        push @users, $user;
    }

    return \@users;
}

sub restoreBackupPreCheck
{
    my ($self, $dir) = @_;

    # get what will be the mode to be restored
    my $mode = $self->_modeToBeRestored($dir);
    if ($mode eq 'slave') {
        # TODO: implement check for slave setups
        return;
    }

    my %etcPasswdUsers = map { $_ => 1 } @{ $self->_usersInEtcPasswd() };

    my @usersToRestore = @{ $self->ldap->usersInBackup($dir, $mode) };
    foreach my $user (@usersToRestore) {
        if (exists $etcPasswdUsers{$user}) {
            throw EBox::Exceptions::External(
                                             __x(
'Cannot restore because LDAP user {user} already exists as /etc/passwd user. Delete or rename this user and try again',
                                                 user => $user
                                                )
                                            );
        }
    }
}

sub restoreConfig
{
    my ($self, $dir) = @_;
    my $mode = mode();

    if ($mode eq 'master' or $mode eq 'ad-slave') {
        EBox::UsersAndGroups::Setup::createDefaultGroupIfNeeded();

        EBox::Sudo::root('/etc/init.d/slapd stop');
        $self->ldap->restoreLdapMaster($dir);
        EBox::Sudo::root('/etc/init.d/slapd start');
        $self->ldap->clearConn();

        # Save conf to enable NSS (and/or) PAM
        $self->_setConf();
        for my $user ($self->users()) {
            $self->initUser($user->{'username'});
        }
    } elsif ($mode eq 'slave') {
        $self->_manageService('stop');
        $self->ldap->restoreLdapReplica($dir);
        $self->ldap->restoreLdapTranslucent($dir);
        $self->ldap->restoreLdapFrontend($dir);
        $self->ldap->clearConn();
        $self->_manageService('start');
        try {
            $self->waitSync();
        } otherwise {
            my $model = EBox::Model::ModelManager->instance()->model('Mode');
            my $remote = $model->remoteValue();
            throw EBox::Exceptions::Internal("Cannot restore slave machine when master is down: $remote");
        };

        # Save conf to enable NSS (and/or) PAM
        $self->_setConf();
        for my $user ($self->users()) {
            $self->initUser($user->{'username'});
        }
        $self->_enforceServiceState();
    } else {
        throw EBox::Exceptions::Internal(
            "Trying to restore configuration of unknown LDAP mode: $mode");
    }
}

sub _removePasswds
{
  my ($self, $file) = @_;

  my $anyPasswdAttr = any(qw(
                              userPassword
                              sambaLMPassword
                              sambaNTPassword
                            )
                         );
  my $passwordSubstitution = "password";

  my $FH_IN;
  open $FH_IN, "<$file" or
    throw EBox::Exceptions::Internal ("Cannot open $file: $!");

  my ($FH_OUT, $tmpFile) = tempfile(DIR => EBox::Config::tmp());

  foreach my $line (<$FH_IN>) {
    my ($attr, $value) = split ':', $line;
    if ($attr eq $anyPasswdAttr) {
      $line = $attr . ': ' . $passwordSubstitution . "\n";
    }

    print $FH_OUT $line;
  }

  close $FH_IN  or
    throw EBox::Exceptions::Internal ("Cannot close $file: $!");
  close $FH_OUT or
    throw EBox::Exceptions::Internal ("Cannot close $tmpFile: $!");

  File::Copy::move($tmpFile, $file);
  unlink $tmpFile;
}


sub minUid
{
    return MINUID;
}

sub minGid
{
    return MINGID;
}


sub defaultGroup
{
    return DEFAULTGROUP;
}

# Method: authUser
#
#   try to authenticate the given user with the given password
#
sub authUser
{
    my ($self, $user, $password) = @_;

    my $authorized = 0;
    my $ldap = EBox::Ldap::safeConnect(EBox::Ldap::LDAPI);
    try {
        EBox::Ldap::safeBind($ldap, $self->userDn($user), $password);
        $authorized = 1; # auth ok
    } otherwise {
        $authorized = 0; # auth failed
    };
    return $authorized;
}

sub shaHasher
{
    my ($password) = @_;
    return '{SHA}' . Digest::SHA1::sha1_base64($password) . '=';
}

sub md5Hasher
{
    my ($password) = @_;
    return '{MD5}' . Digest::MD5::md5_base64($password) . '==';
}

sub lmHasher
{
    my ($password) = @_;
    return Crypt::SmbHash::lmhash($password);
}

sub ntHasher
{
    my ($password) = @_;
    return Crypt::SmbHash::nthash($password);
}

sub digestHasher
{
    my ($password, $user) = @_;
    my $realm = getRealm();
    my $digest = "$user:$realm:$password";
    return '{MD5}' . Digest::MD5::md5_base64($digest) . '==';
}

sub realmHasher
{
    my ($password, $user) = @_;
    my $realm = getRealm();
    my $digest = "$user:$realm:$password";
    return '{MD5}' . Digest::MD5::md5_hex($digest);
}

sub getRealm
{
    # FIXME get the LDAP dc as realm when merged iclerencia/ldap-jaunty-ng
    return 'ebox';
}

sub passwordHasher
{
    my ($format) = @_;

    my $hashers = {
        'sha1' => \&shaHasher,
        'md5' => \&md5Hasher,
        'lm' => \&lmHasher,
        'nt' => \&ntHasher,
        'digest' => \&digestHasher,
        'realm' => \&realmHasher,
    };
    return $hashers->{$format};
}

sub defaultPasswordHash
{
    my ($password) = @_;

    my $format = EBox::Config::configkey('default_password_format');
    if (not defined($format)) {
        $format = 'sha1';
    }
    my $hasher = passwordHasher($format);
    my $hash = $hasher->($password);
    return $hash;
}

sub _setupSlaveLDAP
{
    my ($self, $replicaOnly) = @_;

    # Setup everything by default
    $replicaOnly = 0 unless defined($replicaOnly);

    my ($ldap, $dn) = $self->_connRemoteLDAP();

    # Save LDAP dn in Mode
    my $model = $self->model('Mode');
    my $row = $model->row();
    $row->elementByName('dn')->setValue($dn);
    $row->store();

    $self->_registerHostname($ldap, $dn);
    $self->_getCertificates($ldap, $dn);
    $self->_setupReplication($dn, $replicaOnly);
}

sub _connRemoteLDAP
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $remote = $model->remoteValue();
    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect("ldap://$remote");
    my $dn = baseDn($ldap);
    EBox::Ldap::safeBind($ldap, $self->ldap->rootDn($dn), $password);

    return ($ldap, $dn);
}

sub _registerHostname
{
    my ($self, $ldap, $dn) = @_;

    my $hostname = hostname();

    my %args = (
        'base' => "ou=slaves,$dn",
        'scope' => 'base',
        'filter' => "(hostname=$hostname)"
    );
    my $result = $ldap->search(%args);
    if ($result->count() > 0) {
        throw EBox::Exceptions::External(__x('A host with the name {host} is already registered in this Zentyal', host => $hostname));
    }

    my $apache = EBox::Global->modInstance('apache');
    my $port = $apache->port();

    %args = (
        attr => [
            'objectClass' => 'slaveHost',
            'hostname' => $hostname,
            'port' => $port,
        ]
    );
    $result = $ldap->add("hostname=$hostname,ou=slaves,$dn", %args);
    if($result->is_error()) {
        EBox::debug('Error registering hostname:' . $result->error());
    }
}

sub _getCertificates
{
    my ($self, $ldap, $dn) = @_;

    my %args = (
        'base' => "cn=master,$dn",
        'scope' => 'base',
        'filter' => 'objectClass=masterHost'
    );
    my $result = $ldap->search(%args);
    my $entry = ($result->entries)[0];
    my $cert = $entry->get_value('masterCertificate');
    my $cacert = $entry->get_value('masterCACertificate');
    my $ldapcacert = $entry->get_value('masterLDAPCACertificate');

    write_file(SSL_DIR . 'master.cert', $cert);
    write_file(CA_DIR . 'masterca.pem', $cacert);
    #remove old links pointing to masterca.pem
    opendir(my $dir, CA_DIR);
    while(my $file = readdir($dir)) {
        next unless (-l CA_DIR . $file);
        my $link = readlink (CA_DIR . $file);
        if ($link eq 'masterca.pem') {
            unlink(CA_DIR . $file);
        }
    }
    EBox::Sudo::command('ln -s masterca.pem ' . CA_DIR . '`openssl x509 -hash -noout -in ' . CA_DIR . 'masterca.pem`.0');

    write_file(CA_DIR . 'masterldapca.pem', $ldapcacert);
    EBox::Sudo::root('ln -sf ' . CA_DIR . 'masterldapca.pem /etc/ldap/ssl/masterldapca.pem');
    EBox::Module::Base::writeConfFileNoCheck('/etc/ldap/ldap.conf',
            'usersandgroups/ldap-slave.conf.mas',
    );

}

sub _setupReplication
{
    my ($self, $remotedn, $replicaOnly) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $remote = $model->remoteValue();
    my $password = $model->passwordValue();

    my $opts = [
        'remote' => $remote,
        'remotedn' => $remotedn,
        'password' => $password,
        'schemadir' => EBox::Config::share() . '/ebox-usersandgroups/'
    ];

    my $ldappass = EBox::Config::conf() . 'ebox-ldap.passwd';
    EBox::Module::Base::writeFile($ldappass, $password);

    $self->_writeLdapConf('replica', $opts);

    unless($replicaOnly) {
        $self->_writeLdapConf('translucent', $opts);
        $self->_writeLdapConf('frontend', $opts);

        EBox::Module::Base::writeConfFileNoCheck(
                EBox::Config::tmp() . "slapd-frontend-referrals.ldif",
                "usersandgroups/slapd-frontend-referrals.ldif.mas",
                $opts
                );
        EBox::Sudo::root('slapadd -F ' . LDAPCONFDIR .
                "slapd-frontend.d" .  " -b '$remotedn' -l " .
                EBox::Config::tmp() . "slapd-frontend-referrals.ldif");
        EBox::Sudo::root("chown -R openldap.openldap /var/lib/ldap-frontend");
    }

    $self->_manageService('start');
    $self->waitSync();
    $self->rewriteObjectClassesTree($self->usersDn());
    $self->rewriteObjectClassesTree($self->groupsDn());
    $self->_manageService('stop');
}

sub waitSync
{
    my ($self) = @_;

    unless (mode() eq 'slave') {
        return;
    }

    my $times = 10;
    while (1) {
        my $master_users = $self->listMasterUsers();
        my $replica_users = $self->listReplicaUsers();

        my $master_groups = $self->listMasterGroups();
        my $replica_groups = $self->listReplicaGroups();

        EBox::debug("Master users: " . @{$master_users});
        EBox::debug("Replica users: " . @{$replica_users});
        EBox::debug("Master groups: " . @{$master_groups});
        EBox::debug("Replica groups: " . @{$replica_groups});

        if ((@{$master_users} == @{$replica_users}) and
            (@{$master_groups} == @{$replica_groups})) {
            last;
        }
        $times--;
        if ($times == 0) {
            throw EBox::Exceptions::Internal(__('Replication failed'));
        }
        sleep (3);
    }
}

sub _writeLdapConf
{
    my ($self, $name, $opts) = @_;

    EBox::Module::Base::writeConfFileNoCheck(
        EBox::Config::tmp() . "slapd-$name.ldif",
        "usersandgroups/slapd-$name.ldif.mas",
        $opts
    );

    EBox::Sudo::root('rm -rf ' . LDAPCONFDIR . "slapd-$name.d");
    EBox::Sudo::root('mkdir -p ' . LDAPCONFDIR . "slapd-$name.d");
    EBox::Sudo::root('chmod 750 ' . LDAPCONFDIR . "slapd-$name.d");

    EBox::Sudo::root("rm -rf /var/lib/ldap-$name");
    EBox::Sudo::root("mkdir -p /var/lib/ldap-$name");
    EBox::Sudo::root("chmod 750 /var/lib/ldap-$name");

    EBox::Sudo::root('slapadd -F ' . LDAPCONFDIR . "slapd-$name.d" .
        ' -b "cn=config" -l ' . EBox::Config::tmp() . "slapd-$name.ldif");

    EBox::Sudo::root('chown -R openldap.openldap ' . LDAPCONFDIR . "slapd-$name.d");
    EBox::Sudo::root("chown -R openldap.openldap /var/lib/ldap-$name");
}

sub listUsers
{
    my ($self, $ldap, $dn) = @_;

    my %args = (
        'base' => $self->usersDn($dn),
        'scope' => 'one',
        'filter' => "(objectClass=posixAccount)"
    );
    my $result = $ldap->search(%args);

    my @users = map { $_->get_value('uid') } $result->entries();
    return \@users;
}

sub listMasterUsers
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');

    my $remote = $model->remoteValue();
    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect("ldap://$remote");
    my $dn = baseDn($ldap);
    my $rootdn = $self->ldap->rootDn($dn);
    EBox::Ldap::safeBind($ldap, $rootdn, $password);

    return $self->listUsers($ldap, $dn);
}

sub listReplicaUsers
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect('ldap://127.0.0.1:1389');
    my $dn = baseDn($ldap);
    my $rootdn = $self->ldap->rootDn($dn);
    EBox::Ldap::safeBind($ldap, $rootdn, $password);

    return $self->listUsers($ldap, $dn);
}

sub listGroups
{
    my ($self, $ldap, $dn) = @_;

    my %args = (
        'base' => $self->groupsDn($dn),
        'scope' => 'one',
        'filter' => "(objectClass=posixGroup)"
    );
    my $result = $ldap->search(%args);

    my @groups = map { $_->get_value('cn') } $result->entries();
    return \@groups;
}

sub listMasterGroups
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');

    my $remote = $model->remoteValue();
    my $password = $model->passwordValue();


    my $ldap = EBox::Ldap::safeConnect("ldap://$remote");
    my $dn = baseDn($ldap);
    my $rootdn = $self->ldap->rootDn($dn);
    EBox::Ldap::safeBind($ldap, $rootdn, $password);

    return $self->listGroups($ldap, $dn);
}

sub listReplicaGroups
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');

    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect('ldap://127.0.0.1:1389');
    my $dn = baseDn($ldap);
    my $rootdn = $self->ldap->rootDn($dn);
    EBox::Ldap::safeBind($ldap, $rootdn, $password);

    return $self->listGroups($ldap, $dn);
}

sub listSchemas
{
    my ($self, $ldap) = @_;

    my %args = (
        'base' => 'cn=schema,cn=config',
        'scope' => 'one',
        'filter' => "(objectClass=olcSchemaConfig)"
    );
    my $result = $ldap->search(%args);

    my @schemas = map { $_->get_value('cn') } $result->entries();
    return \@schemas;
}

sub listMasterSchemas
{
    my ($self) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');

    my $remote = $model->remoteValue();
    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect("ldap://$remote");
    my $dn = baseDn($ldap);
    EBox::Ldap::safeBind($ldap, $self->ldap->rootDn($dn), $password);

    return $self->listSchemas($ldap);
}

sub listReplicaSchemas
{
    my ($self, $port) = @_;

    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $password = $model->passwordValue();

    my $ldap = EBox::Ldap::safeConnect("ldap://127.0.0.1:$port");
    my $dn = baseDn($ldap);
    my $rootdn = $self->ldap->rootDn($dn);
    EBox::Ldap::safeBind($ldap, $rootdn, $password);

    return $self->listSchemas($ldap);
}

sub listSlaves
{
    my ($self) = @_;

    my %args = (
        'base' => $self->slavesDn(),
        'scope' => 'sub',
        'filter' => "(objectClass=slaveHost)"
    );
    my $result = $self->ldap->search(\%args);

    my @slaves = map {
        {
            'hostname' => $_->get_value('hostname'),
            'port' => $_->get_value('port')
        }
    } $result->entries();
    return \@slaves;
}

sub slaveInfo
{
    my ($self, $slave) = @_;

    my %args = (
        'base' => $self->slavesDn(),
        'scope' => 'sub',
        'filter' => "(hostname=$slave)"
    );
    my $result = $self->ldap->search(\%args);

    my $slaveInfo;

    if ($result->count()) {
        my $entry = ($result->entries)[0];
        $slaveInfo = {
            'hostname' => $entry->get_value('hostname'),
            'port' => $entry->get_value('port')
        };
    }
    return $slaveInfo;
}

sub deleteSlave
{
    my ($self, $slave) = @_;
    my $res = 0;
    try {
        $self->ldap->delete("hostname=$slave," . $self->slavesDn());
        my $journaldir = $self->_journalsDir . $slave;
        if (-d $journaldir) {
            EBox::Sudo::root('rm -rf ' . $journaldir);
        }
    } otherwise {
        EBox::debug('Error deleting slave: ' . $slave);
        $res = 1;
    };
    return $res;
}

sub mode
{
    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $mode = $model->modeValue();

    return $mode;
}

sub remoteLdap
{
    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $remote = $model->remoteValue();

    return $remote;
}

sub remotePassword
{
    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $password = $model->passwordValue();

    return $password;
}

sub baseDn
{
    my ($ldap) = @_;

    my %args = (
        'base' => '',
        'scope' => 'base',
        'filter' => '(objectclass=*)',
        'attrs' => ['namingContexts']
    );
    my $result = $ldap->search(%args);
    my $entry = ($result->entries)[0];
    my $attr = ($entry->attributes)[0];
    my $dn = $entry->get_value($attr);

    return $dn;
}

sub _loginShell
{
    my ($self) = @_;

    return $self->model('PAM')->login_shellValue();
}

sub _homeDirectory
{
    my ($username) = @_;

    my $home = HOMEPATH . '/' . $username;
    return $home;
}

sub _setupNSSPAM
{
    my ($self) = @_;

    my @array;
    my $umask = EBox::Config::configkey('dir_umask');
    push (@array, 'umask' => $umask);

    $self->writeConfFile(AUTHCONFIGTMPL, 'usersandgroups/acc-ebox.mas',
               \@array);

    my $enablePam = $self->model('PAM')->enable_pamValue();
    my @cmds;
    push (@cmds, 'auth-client-config -a -p ebox');

    unless ($enablePam) {
        push (@cmds, 'auth-client-config -a -p ebox -r');
    }

    push (@cmds, 'auth-client-config -t nss -p ebox');
    EBox::Sudo::root(@cmds);
}

1;
