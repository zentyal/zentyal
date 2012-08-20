# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::LDB;

use strict;
use warnings;

use EBox::Samba::LdbObject;
use EBox::Samba::Credentials;
use EBox::Samba::User;
use EBox::Samba::Group;

use EBox::LDB::IdMapDb;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataExists;

use Net::LDAP;
use Net::LDAP::Control;
use Net::LDAP::Util qw(ldap_error_name);
use Authen::SASL qw(Perl);
use IO::Socket::UNIX;

use Data::Dumper;
use Date::Calc;
use Encode;
use Error qw( :try );

use constant LDAPI => "ldapi://%2fvar%2flib%2fsamba%2fprivate%2fldap_priv%2fldapi";
use constant SOCKET_PATH => '/var/run/ldb';

# Singleton variable
my $_instance = undef;

sub _new_instance
{
    my $class = shift;

    my $self = {};
    $self->{ldb} = undef;
    $self->{idamp} = undef;
    bless ($self, $class);
    return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::Ldap>
#
# Returns:
#
#   object of class <EBox::Ldap>
sub instance
{
    my ($self, %opts) = @_;

    unless (defined ($_instance)) {
        $_instance = EBox::LDB->_new_instance();
    }

    return $_instance;
}

# Method: idmap
#
#   Returns an instance of IdMapDb.
#
sub idmap
{
    my ($self) = @_;

    unless (defined $self->{idmap}) {
        $self->{idmap} = EBox::LDB::IdMapDb->new();
    }
    return $self->{idmap};
}

# Method: syncCon
#
#   Returns the socket connection used by the Zentyal
#   ldb module
#
# Returns:
#
# Exceptions:
#
#   Internal - If connection can't be created
#
sub syncCon
{
    my ($self) = @_;

    # Workaround to detect if connection is broken and force reconnection
    my $reconnect = 1;
    if (defined $self->{sync}) {
        my $socket = $self->{sync};
        if (tell ($socket)) {
            print $socket "PING\n";
            my $answer = <$socket>;
            if (defined $answer) {
                chomp $answer;
                if ($answer eq 'PONG') {
                    $reconnect = 0;
                }
            }
        }
    }

    if ($reconnect) {
        $self->{sync} = $self->safeConnectSync(SOCKET_PATH);
    }

    return $self->{sync};
}

# Method: ldbCon
#
#   Returns the Net::LDAP connection used by the module
#
# Returns:
#
#   An object of class Net::LDAP whose connection has already bound
#
# Exceptions:
#
#   Internal - If connection can't be created
#
sub ldbCon
{
    my ($self) = @_;

    # Workaround to detect if connection is broken and force reconnection
    my $reconnect = 0;
    if (defined $self->{ldb}) {
        my $mesg = $self->{ldb}->search(
                base   => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS' ) {
            $self->clearConn();
            $reconnect = 1;
        }
    }

    if (not defined $self->{ldb} or $reconnect) {
        $self->{ldb} = $self->safeConnect();
    }

    return $self->{ldb};
}

sub safeConnectSync
{
    my ($self, $uri) = @_;

    my $retries = 4;
    my $socket = undef;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to sync socket');
    };

    while (not $socket = IO::Socket::UNIX->new(
                Peer  => SOCKET_PATH,
                Type  => SOCK_STREAM,
                Timeout => 5) and $retries--) {
        my $samba = EBox::Global->modInstance('samba');
        $samba->_manageService('start');
        EBox::error("Couldn't connect to synchronizer $uri, retrying");
        sleep (5);
    }

    unless ($socket) {
        throw EBox::Exceptions::External(
            "FATAL: Couldn't connect to synchronizer: $uri");
    }

    if ($retries < 3) {
        EBox::info('Synchronizer reconnect successful');
    }

    return $socket;
}

sub safeConnect
{
    my ($self) = @_;

    my $retries = 4;
    my $ldb;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to samba LDAP');
    };

    while (not $ldb = Net::LDAP->new(LDAPI) and $retries--) {
        my $samba = EBox::Global->modInstance('samba');
        unless ($samba->isRunning()) {
            EBox::debug("Samba daemon was stopped, starting it");
            $samba->_manageService('start');
            sleep (5);
            next;
        }
        EBox::error("Couldn't connect to samba LDAP server: $@, retrying");
        sleep (5);
    }

    unless ($ldb) {
        throw EBox::Exceptions::External(
            "FATAL: Couldn't connect to samba LDAP server");
    }

    if ($retries <= 3) {
        EBox::debug("Reconnected successfully");
    }

    return $ldb;
}

# Method: dn
#
#   Returns the base DN (Distinguished Name)
#
# Returns:
#
#   string - DN
#
sub dn
{
    my ($self) = @_;

    unless (defined ($self->{dn})) {
        my $params = {
            base => '',
            scope => 'base',
            filter => 'cn=*',
            attrs => ['defaultNamingContext'],
        };
        my $msg = $self->search($params);
        if ($msg->count() == 1) {
            my $entry = $msg->entry(0);
            $self->{dn} = $entry->get_value('defaultNamingContext');
        }
    }

    return defined ($self->{dn}) ? $self->{dn} : '';
}

# Method: clearConn
#
#   Closes LDAP connection and clears DN cached value
#
sub clearConn
{
    my ($self) = @_;

    if (defined $self->{ldb}) {
        $self->{ldb}->disconnect();
    }

    delete $self->{dn};
    delete $self->{ldb};
}

# Method: search
#
#   Performs a search in the LDB database using Net::LDAP.
#
# Parameters:
#
#   args - arguments to pass to Net::LDAP->search()
#
# Exceptions:
#
#   Internal - If there is an error during the search
#
sub search
{
    my ($self, $args) = @_;

    my $ldb = $self->ldbCon();
    my $result = $ldb->search(%{$args});
    $self->_errorOnLdap($result, $args);

    return $result;
}

# Method: modify
#
#   Performs a modification in the LDB database using Net::LDAP.
#
# Parameters:
#
#   dn   - dn where to perform the modification
#   args - parameters to pass to Net::LDAP->modify()
#
# Exceptions:
#
#   Internal - If there is an error during the operation
#
sub modify
{
    my ($self, $dn, $args) = @_;

    my $ldb = $self->ldbCon();
    my $result = undef;
    try {
        $self->disableZentyalModule();
        $result = $ldb->modify($dn, %{$args});
        $self->_errorOnLdap($result, $args);
    } otherwise {
        my $error = shift;
        throw $error;
    } finally {
        $self->enableZentyalModule();
    };

    return $result;
}

# Method: delete
#
#   Performs a deletion in the LDB database using Net::LDAP
#
# Parameters:
#
#   dn - dn to delete
#
# Exceptions:
#
#   Internal - If there is an error during the operation
#
sub delete
{
    my ($self, $dn) = @_;

    my $ldb = $self->ldbCon();
    my $result = undef;
    try {
        $self->disableZentyalModule();
        $result = $ldb->delete($dn);
        $self->_errorOnLdap($result, $dn);
    } otherwise {
        my $error = shift;
        throw $error;
    } finally {
        $self->enableZentyalModule();
    };

    return $result;
}

# Method: add
#
#   Adds an object or attributes in the LDB database using Net::LDAP
#
# Parameters:
#
#   dn - dn to add
#   args - parameters to pass to Net::LDAP->add()
#
# Exceptions:
#
#   Internal - If there is an error during the operation
#
sub add
{
    my ($self, $dn, $args) = @_;

    my $ldb = $self->ldbCon();
    my $result = undef;
    try {
        $self->disableZentyalModule();
        $result = $ldb->add($dn, %{$args});
        $self->_errorOnLdap($result, $args);
    } otherwise {
        my $error = shift;
        throw $error;
    } finally {
        $self->enableZentyalModule();
    };

    return $result;
}

# Method: _errorOnLdap
#
#   Check the result for errors
#
sub _errorOnLdap
{
    my ($self, $result, $args) = @_;

    my @frames = caller (2);
    if ($result->is_error()) {
        if ($args) {
            EBox::error( Dumper($args) );
        }
        throw EBox::Exceptions::Internal("Unknown error at " .
                                         $frames[3] . " " .
                                         $result->error);
    }
}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method: enableZentyalModule
#
#   Adds the zentyal module to LDB
#
sub enableZentyalModule
{
    my ($self) = @_;

    my $socket = $self->syncCon();
    print $socket "ENABLE\n";
    $socket->flush();
    # Wait for answer
    my $r = <$socket>;
    chomp $r;
}

# Method: disableZentyalModule
#
#   Disable the zentyal module to LDB
#
sub disableZentyalModule
{
    my ($self) = @_;

    my $socket = $self->syncCon();
    print $socket "DISABLE\n";
    $socket->flush();
    my $r = <$socket>;
    chomp $r;
}

# Method domainSID
#
#   Get the domain SID
#
# Returns:
#
#   string - The SID string of the domain
#
sub domainSID
{
    my ($self) = @_;

    my $base = $self->dn();
    my $params = {
        base => $base,
        scope => 'base',
        filter => "(distinguishedName=$base)",
        attrs => ['objectSid'],
    };
    my $msg = $self->search($params);
    if ($msg->count() == 1) {
        my $entry = $msg->entry(0);
        my $object = new EBox::Samba::LdbObject(entry => $entry);
        return $object->sid();
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'domain', value => $base);
    }
}

sub domainNetBiosName
{
    my ($self) = @_;

    my $realm = EBox::Global->modInstance('users')->kerberosRealm();
    my $params = {
        base => 'CN=Partitions,CN=Configuration,' . $self->dn(),
        scope => 'sub',
        filter => "(&(nETBIOSName=*)(dnsRoot=$realm))",
        attrs => ['nETBIOSName'],
    };
    my $result = $self->search($params);
    if ($result->count() == 1) {
        my $entry = $result->entry(0);
        my $name = $entry->get_value('nETBIOSName');
        return $name;
    }
    return undef;
}

sub ldapUsersToLdb
{
    my ($self) = @_;

    try {
        EBox::info('Loading Zentyal users into samba database');
        my $usersModule = EBox::Global->modInstance('users');
        my $users = $usersModule->users();
        foreach my $user (@{$users}) {
            my $dn = $user->dn();
            EBox::debug("Loading user $dn");
            try {
                my $samAccountName = $user->get('uid');
                my $params = {
                    uidNumber    => scalar ($user->get('uidNumber')),
                    sn           => scalar ($user->get('sn')),
                    givenName    => scalar ($user->get('givenName')),
                    description  => scalar ($user->get('description')),
                    kerberosKeys => $user->kerberosKeys(),
                };
                EBox::Samba::User->create($samAccountName, $params);
            } otherwise {
                my $error = shift;
                EBox::error("Error loading user '$dn': $error");
            };
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    };
}

sub ldapGroupsToLdb
{
    my ($self) = @_;

    try {
        EBox::info('Loading Zentyal groups into samba database');
        my $usersModule = EBox::Global->modInstance('users');
        my $groups = $usersModule->groups();
        foreach my $group (@{$groups}) {
            my $dn = $group->dn();
            EBox::debug("Loading group $dn");
            try {
                my $samAccountName = $group->get('cn');
                my $params = {
                    gidNumber => scalar ($group->get('gidNumber')),
                    description => scalar ($group->get('description')),
                };
                my $createdGroup = EBox::Samba::Group->create($samAccountName, $params);
                foreach my $user (@{$group->users()}) {
                    try {
                        my $smbUser = new EBox::Samba::User(samAccountName => $user->get('uid'));
                        $createdGroup->addMember($smbUser);
                    } otherwise {
                        my $error = shift;
                        EBox::error("Error adding member: $error");
                    };
                }
            } otherwise {
                my $error = shift;
                EBox::error("Error loading group '$dn': $error");
            };
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    };
}

sub ldapServicePrincipalsToLdb
{
    my ($self) = @_;

    EBox::info('Loading Zentyal service principals into samba database');
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();
    my $fqdn = $sysinfo->fqdn();

    my $modules = EBox::Global->modInstancesOfType('EBox::KerberosModule');
    foreach my $module (@{$modules}) {
        my $principals = $module->kerberosServicePrincipals();
        my $samAccountName = "$principals->{service}-$hostname";
        try {
            my $smbUser = new EBox::Samba::User(samAccountName => $samAccountName);
            unless ($smbUser->exists()) {
                # Get the heimdal user to extract the kerberos keys. All service
                # principals for each module should have the same keys, so take
                # the first one.
                my $usersModule = EBox::Global->modInstance('users');
                my $p = @{$principals->{principals}}[0];
                my $baseDn = $usersModule->ldap->dn();
                my $realm = $usersModule->kerberosRealm();
                my $dn = "krb5PrincipalName=$p/$fqdn\@$realm,ou=Kerberos,$baseDn";
                my $user = new EBox::UsersAndGroups::User(dn => $dn);

                my $params = {
                    description  => scalar ($user->get('description')),
                    kerberosKeys => $user->kerberosKeys(),
                };
                $smbUser = EBox::Samba::User->create($samAccountName, $params);
                $smbUser->setCritical(1);
                $smbUser->setViewInAdvancedOnly(1);
            }
            foreach my $p (@{$principals->{principals}}) {
                try {
                    my $spn = "$p/$fqdn";
                    EBox::debug("Adding SPN '$spn' to user " . $smbUser->dn());
                    $smbUser->addSpn($spn);
                } otherwise {
                    my $error = shift;
                    EBox::error("Error adding SPN '$p' to account '$samAccountName': $error");
                };
            }
        } otherwise {
            my $error = shift;
            EBox::error("Error adding account '$samAccountName': $error");
        };
    }
}

sub users
{
    my ($self) = @_;

    my $params = {
        base => 'CN=Users,' . $self->dn(),
        scope => 'sub',
        filter => '(&(objectclass=user)(!(showInAdvancedViewOnly=*))(!(isDeleted=*)))',
        attrs => ['samAccountName', 'givenName', 'sn', 'name', 'description',
                  'uidNumber', 'supplementalCredentials', 'unicodePwd',
                  'objectSid'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('samAccountName')) {
        my $user = new EBox::Samba::User(entry => $entry);
        push (@{$list}, $user);
    }
    return $list;
}

sub groups
{
    my ($self) = @_;

    my $params = {
        base => 'CN=Users,' . $self->dn(),
        scope => 'sub',
        filter => '(&(objectclass=group)(!(showInAdvancedViewOnly=*))(!(isDeleted=*)))',
        attrs => ['samAccountName', 'cn', 'description', 'gidNumber', 'objectSid', 'member'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('samAccountName')) {
        my $group = new EBox::Samba::Group(entry => $entry);
        push (@{$list}, $group);
    }
    return $list;
}

sub ldbUsersToLdap
{
    my ($self) = @_;

    try {
        EBox::info('Loading Samba users into Zentyal LDAP');
        my $usersModule = EBox::Global->modInstance('users');
        my $users = $self->users();
        foreach my $sambaUser (@{$users}) {
            my $dn = $sambaUser->dn();
            EBox::info("Adding user '$dn'");
            my $user = undef;
            try {
                my $params = {};
                $params->{user}      = $sambaUser->get('samAccountName');
                $params->{fullname}  = $sambaUser->get('name');
                $params->{givenname} = defined (scalar ($sambaUser->get('givenName'))) ?
                    $sambaUser->get('givenName') : $sambaUser->get('samAccountName');
                $params->{surname}   = defined (scalar ($sambaUser->get('sn'))) ?
                    $sambaUser->get('sn') : $sambaUser->get('samAccountName');
                $params->{comment}   = defined (scalar ($sambaUser->get('description'))) ?
                    $sambaUser->get('description') : undef;

                my %optParams;
                $optParams{ignoreMods} = ['samba'];
                $user = EBox::UsersAndGroups::User->create($params, 0, %optParams);
            } catch EBox::Exceptions::DataExists with {
                $user = $usersModule->user($sambaUser->get('samAccountName'));
            } otherwise {
                my $error = shift;
                EBox::error("Error loading user '$dn': $error");
                next;
            };

            try {
                my $suppCred    = $sambaUser->get('supplementalCredentials');
                my $unicodePwd  = $sambaUser->get('unicodePwd');
                my $credentials = new EBox::Samba::Credentials(supplementalCredentials => $suppCred, unicodePwd => $unicodePwd);
                $user->setKerberosKeys($credentials->kerberosKeys());
            } otherwise {
                my $error = shift;
                EBox::error("Error setting kerberos keys: $error");
            };

            try {
                # Set the uid mapping
                my $uidNumber = $user->get('uidNumber');
                $sambaUser->set('uidNumber', $uidNumber);
                my $type = $self->idmap->TYPE_UID();
                my $sid = $sambaUser->sid();
                $self->idmap->setupNameMapping($sid, $type, $uidNumber);
            } otherwise {
                my $error = shift;
                EBox::error("Error setting uid mapping: $error");
            };
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    };
}

sub ldbGroupsToLdap
{
    my ($self) = @_;

    try {
        EBox::info('Loading Samba groups into Zentyal LDAP');
        my $usersModule = EBox::Global->modInstance('users');
        my $groups = $self->groups();
        foreach my $sambaGroup (@{$groups}) {
            my $dn = $sambaGroup->dn();
            my $name = $sambaGroup->get('samAccountName');
            my $comment = $sambaGroup->get('description');
            my $zentyalGroup = undef;
            try {
                my %optParams;
                $optParams{ignoreMods} = ['samba'];
                EBox::info("Adding group '$dn'");
                $zentyalGroup = EBox::UsersAndGroups::Group->create($name, $comment, 0, %optParams);
            } catch EBox::Exceptions::DataExists with {
                $zentyalGroup = $usersModule->group($name);
            } otherwise {
                my $error = shift;
                EBox::error("Error adding group '$dn': $error");
                next;
            };

            try {
                # Set the gid mapping
                my $gidNumber = $zentyalGroup->get('gidNumber');
                $sambaGroup->set('gidNumber', $gidNumber);
                my $type = $self->idmap->TYPE_GID();
                my $sid = $sambaGroup->sid();
                $self->idmap->setupNameMapping($sid, $type, $gidNumber);
            } otherwise {
                my $error = shift;
                EBox::error("Error setting up gid mapping: $error");
            };

            # Sync group memebers
            my @members = $sambaGroup->get('member');
            foreach my $sambaDN (@members) {
                try {
                    my $sambaMember = new EBox::Samba::User(dn => $sambaDN);
                    my $zentyalUser = $usersModule->user($sambaMember->get('samAccountName'));
                    $zentyalGroup->addMember($zentyalUser);
                } otherwise {
                    my $error = shift;
                    EBox::error("Error adding member to group '$dn': $error");
                };
            }
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    };
}

1;
