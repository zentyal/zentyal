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

use EBox::LDB::Credentials;
use EBox::LDB::IdMapDb;
use EBox::Exceptions::DataNotFound;

use Net::LDAP;
use Net::LDAP::Control;
use Net::LDAP::Util qw(ldap_error_name);
use IO::Socket::UNIX;

use Data::Dumper;
use Date::Calc;
use Encode;
use Error qw( :try );

use constant LDAPI => "ldapi://%2fvar%2flib%2fsamba%2fprivate%2fldapi";
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
#   Returns the socket connection used by the module
#
# Returns:
#
#
# Exceptions:
#
#   Internal - If connection can't be created
#
sub syncCon
{
    my ($self) = @_;

    # Workaround to detect if connection is broken and force reconnection
    # NOTE this will fail always until implement threaded synchronizer
    my $reconnect = 0;
    if (defined $self->{sync}) {
        my $socket = $self->{sync};
        print $socket "PING\n";
        my $answer = <$socket>;
        chomp $answer;
        if ($answer ne 'PONG') {
            $reconnect = 1;
        }
    }

    if (not defined $self->{sync} or $reconnect) {
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
        $self->{ldb} = $self->safeConnect(LDAPI);

        my $dn   = $self->zentyalDn();
        my $pass = $self->getPassword();

        $self->safeBind($self->{ldb}, $dn, $pass);
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
    my ($self, $uri) = @_;

    my $retries = 4;
    my $ldb;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to LDB');
    };

    while (not $ldb = Net::LDAP->new($uri) and $retries--) {
        my $samba = EBox::Global->modInstance('samba');
        $samba->_manageService('start');
        EBox::error("Couldn't connect to LDB server $uri, retrying");
        sleep (5);
    }

    unless ($ldb) {
        throw EBox::Exceptions::External(
            "FATAL: Couldn't connect to LDB server: $uri");
    }

    if ($retries < 3) {
        EBox::info('LDB reconnect successful');
    }

    return $ldb;
}

sub safeBind
{
    my ($self, $ldb, $dn, $password) = @_;

    my $bind = $ldb->bind($dn, password => $password);
    unless ($bind->{resultCode} == 0) {
        throw EBox::Exceptions::External(
            'Couldn\'t bind to LDB server, result code: ' .
            $bind->{resultCode});
    }

    return $bind;
}

# Method: zentyalDn
#
#   Returns the dn of the priviliged user
#
# Returns:
#
#   string - The zentyal user DN
#
sub zentyalDn
{
    my ($self, $base) = @_;

    unless (defined ($base)) {
        $base = $self->dn();
    }

    return 'cn=zentyal,cn=Users,' . $base;
}

# Method: getPassword
#
#   Returns the password used to connect to the LDB
#
# Returns:
#
#   string - password
#
# Exceptions:
#
#   External - If password can't be read
#
sub getPassword
{
    my ($self) = @_;

    unless (defined ($self->{password})) {
        my $path = EBox::Config->conf() . "ldb.passwd";

        open (PASSWD, $path) or
            throw EBox::Exceptions::External('Could not get LDB password');
        my $pwd = <PASSWD>;
        close (PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{password} = $pwd;
    }

    return $self->{password};
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
        my $ldb = $self->safeConnect(LDAPI);

        $ldb->bind();

        my %args = ( base   => '',
                     scope  => 'base',
                     filter => '(objectclass=*)',
                     attrs  => ['namingContexts'] );
        my $result = $ldb->search(%args);
        if ($result->count() > 0) {
            my $entry = ($result->entries)[0];
            my @attributes = $entry->attributes();
            if (scalar @attributes > 0) {
                my $attr = $attributes[0];
                $self->{dn} = $entry->get_value($attr);
            }
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
        $self->{ldb}->unbind();
        $self->{ldb}->disconnect();
    }

    delete $self->{dn};
    delete $self->{ldb};
    delete $self->{password};
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
    my $result = $ldb->modify($dn, %{$args});
    $self->_errorOnLdap($result, $args);

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
    my $result = $ldb->delete($dn);
    $self->_errorOnLdap($result, $dn);

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
    my $result = $ldb->add($dn, %{$args});
    $self->_errorOnLdap($result, $args);

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

# Method: addZentyalModule
#
#   Adds the zentyal module to LDB
#
sub enableZentyalModule
{
    my ($self) = @_;

    EBox::debug('Enabling Zentyal LDB module');
    my $socket = $self->syncCon();
    print $socket "ENABLE\n";
    $socket->flush;
    $socket->close;
}

# Method: disableZentyalModule
#
#   Disable the zentyal module to LDB
#
sub disableZentyalModule
{
    my ($self) = @_;

    EBox::debug('Disabling Zentyal LDB module');
    my $socket = $self->syncCon();
    print $socket "DISABLE\n";
    $socket->flush;
    $socket->close;
}

sub changeUserPassword
{
    my ($self, $dn, $newPasswd, $oldPasswd) = @_;

    my $ldb = $self->ldbCon();
    my $rootdse = $ldb->root_dse();
    if ($rootdse->supported_extension('1.3.6.1.4.1.4203.1.11.1')) {
        # Update the password using the LDAP extension
        require Net::LDAP::Extension::SetPassword;
        my $mesg = $ldb->set_password(user => $dn,
                                      oldpasswd => $oldPasswd,
                                      newpasswd => $newPasswd);
        $self->_errorOnLdap($mesg);
    } else {
        my $unicodePwd = encode('UTF16-LE', "\"$newPasswd\"");
        my $mesg = $ldb->modify($dn, changes => [ replace => [ unicodePwd => $unicodePwd ] ]);
    }
}

# Method getIdByDN
#
#   Get samAccountName by object's DN
#
# Parameters:
#
#   dn - The DN of the object
#
# Returns:
#
#   The samAccountName of the object
#
sub getIdByDN
{
    my ($self, $dn) = @_;

    my $args = { base   => $dn,
                 scope  => 'base',
                 filter => "(dn=$dn)",
                 attrs  => ['sAMAccountName'] };
    my $result = $self->search($args);
    if ($result->count() == 1) {
        my $entry = $result->entry(0);
        my $value = $entry->get_value('sAMAccountName');
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound( data=> 'DN', value => $dn);
    }
}

# Method getSidById
#
#   Get SID by object's sAMAccountName
#
# Parameters:
#
#   id - The ID of the object
#
# Returns:
#
#   The SID of the object
#
sub getSidById
{
    my ($self, $objectId) = @_;

    my $args = { base   => $self->dn(),
                 scope  => 'sub',
                 filter => "(sAMAccountName=$objectId)",
                 attrs  => ['objectSid'] };
    my $result = $self->search($args);
    if ($result->count() == 1) {
        my $entry = $result->entry(0);
        my $value = $entry->get_value('objectSid');
        my $string = $self->sidToString($value);
        return $string;
    } else {
        throw EBox::Exceptions::DataNotFound( data =>'sAMAccountName', value => $objectId);
    }
}

sub sidToString
{
    my ($self, $sid) = @_;

    return undef
        unless unpack("C", substr($sid, 0, 1)) == 1;

    return undef
        unless length($sid) == 8 + 4 * unpack("C", substr($sid, 1, 1));

    my $sid_str = "S-1-";

    $sid_str .= (unpack("C", substr($sid, 7, 1)) +
                (unpack("C", substr($sid, 6, 1)) << 8) +
                (unpack("C", substr($sid, 5, 1)) << 16) +
                (unpack("C", substr($sid, 4, 1)) << 24));

    for my $loop (0 .. unpack("C", substr($sid, 1, 1)) - 1) {
        $sid_str .= "-" . unpack("I", substr($sid, 4 * $loop + 8, 4));
    }

    return $sid_str;
}

sub stringToSid
{
    my ($self, $sidString) = @_;

    return undef
        unless uc(substr($sidString, 0, 4)) eq "S-1-";

    my ($auth_id, @sub_auth_id) = split(/-/, substr($sidString, 4));

    my $sid = pack("C4", 1, $#sub_auth_id + 1, 0, 0);

    $sid .= pack("C4", ($auth_id & 0xff000000) >> 24, ($auth_id &0x00ff0000) >> 16,
            ($auth_id & 0x0000ff00) >> 8, $auth_id &0x000000ff);

    for my $loop (0 .. $#sub_auth_id) {
        $sid .= pack("I", $sub_auth_id[$loop]);
    }

    return $sid;
}

sub guidToString
{
    my ($self, $guid) = @_;

    return sprintf "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
           unpack("I", $guid),
           unpack("S", substr($guid, 4, 2)),
           unpack("S", substr($guid, 6, 2)),
           unpack("C", substr($guid, 8, 1)),
           unpack("C", substr($guid, 9, 1)),
           unpack("C", substr($guid, 10, 1)),
           unpack("C", substr($guid, 11, 1)),
           unpack("C", substr($guid, 12, 1)),
           unpack("C", substr($guid, 13, 1)),
           unpack("C", substr($guid, 14, 1)),
           unpack("C", substr($guid, 15, 1));
}

sub stringToGuid
{
    my ($self, $guidString) = @_;

    return undef
        unless $guidString =~ /([0-9,a-z]{8})-([0-9,a-z]{4})-([0-9,a-z]{4})-([0-9,a-z]{2})([0-9,a-z]{2})-([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})/i;

    return pack("I", hex $1) . pack("S", hex $2) . pack("S", hex $3) .
           pack("C", hex $4) . pack("C", hex $5) . pack("C", hex $6) .
           pack("C", hex $7) . pack("C", hex $8) . pack("C", hex $9) .
           pack("C", hex $10) . pack("C", hex $11);
}

sub ldapUsersToLdb
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');

    # This control is defined in the samba header file 'samdb.h'
    # and allow to write protected attributes like unicodePwd and
    # supplementalCredentials
    my $bypassControl = Net::LDAP::Control->new(
        type => '1.3.6.1.4.1.7165.4.3.12',
        critical => 1 );

    try {
        # Disable the Zentyal LDB module, otherwise all operations will be
        # forwarded back to zentyal
        $self->disableZentyalModule();

        EBox::info('Loading Zentyal users into samba database');
        my $users = $usersMod->users();
        foreach my $user (@{$users}) {
            my $dn = $user->dn();
            $dn =~ s/OU=Users/CN=Users/i;
            $dn =~ s/uid=/CN=/i;
            EBox::debug("Loading user $dn");
            try {
                my $samAccountName = $user->get('uid');
                my $sn = $user->get('sn');
                my $givenName = $user->get('givenName');
                my $principal = $user->get('krb5PrincipalName');
                my $description = $user->get('description');
                my $kerberosKeys = $user->kerberosKeys();
                my $credentials = EBox::LDB::Credentials::encodeSambaCredentials($kerberosKeys);

                my $attrs = [];
                push ($attrs, objectClass       => [ 'top', 'person', 'organizationalPerson', 'user' ]);
                push ($attrs, sAMAccountName    => $samAccountName);
                push ($attrs, userAccountControl => '512');
                push ($attrs, sn                => $sn);
                push ($attrs, givenName         => $givenName);
                push ($attrs, userPrincipalName => $principal);
                push ($attrs, description       => $description) if defined $description;
                if (defined $credentials->{supplementalCredentials}) {
                    push ($attrs, supplementalCredentials => $credentials->{supplementalCredentials});
                }
                if (defined $credentials->{unicodePwd}) {
                    push ($attrs, unicodePwd    => $credentials->{unicodePwd});
                }
                if (defined $credentials->{supplementalCredentials} or
                    defined $credentials->{unicodePwd}) {
                    # NOTE If this value is not set samba sigfault
                    # This value is stored as a large integer that represents
                    # the number of 100 nanosecond intervals since January 1, 1601 (UTC)
                    my ($sec, $min, $hour, $day, $mon, $year) = gmtime(time);
                    $year = $year + 1900;
                    $mon += 1;
                    my $days = Date::Calc::Delta_Days(1601, 1, 1, $year, $mon, $day);
                    my $secs = $sec + $min * 60 + $hour * 3600 + $days * 86400;
                    my $val = $secs * 10000000;
                    push ($attrs, pwdLastSet => $val);
                }
                $self->add($dn, { attrs => $attrs, control => $bypassControl });

                # Map UID
                my $type = $self->idmap->TYPE_UID();
                my $sid = $self->getSidById($samAccountName);
                my $uidNumber = $user->get('uidNumber');
                $self->idmap->setupNameMapping($sid, $type, $uidNumber);
            } otherwise {
                my $error = shift;
                EBox::error("Error loading user '$dn': $error");
            };
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    } finally {
        $self->enableZentyalModule();
    };
}

sub ldapGroupsToLdb
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');

    try {
        # Disable the Zentyal LDB module, otherwise all operations will be
        # forwarded back to zentyal
        $self->disableZentyalModule();
        EBox::debug('Loading Zentyal groups into samba database');

        my $groups = $usersMod->groups();
        foreach my $group (@{$groups}) {
            my $dn = $group->dn();
            $dn =~ s/OU=Groups/CN=Users/i;
            my $cn = $group->get('cn');
            my $samAccountName = $group->get('cn');
            my $description = $group->get('description');
            EBox::debug("Loading group $dn");
            try {
                my $attrs = [];
                push ($attrs, objectClass    => ['top', 'group']);
                push ($attrs, sAMAccountName => $cn);
                push ($attrs, cn             => $cn);
                push ($attrs, description    => $description) if defined ($description);

                my $groupUsers = [];
                foreach my $user (@{$group->users()}) {
                    my $dn = $user->dn();
                    $dn =~ s/OU=Users/CN=Users/i;
                    $dn =~ s/uid=/CN=/i;
                    push ($groupUsers, $dn);
                }
                push ($attrs, member => $groupUsers) if scalar @{$groupUsers};

                $self->add($dn, { attrs => $attrs });
            } otherwise {
                my $error = shift;
                EBox::error("Error loading group '$dn': $error");
            };

            # TODO Map the gid
            my $type = $self->idmap->TYPE_GID();
            my $sid = $self->getSidById($samAccountName);
            my $uidNumber = $group->get('gidNumber');
            $self->idmap->setupNameMapping($sid, $type, $uidNumber);
        }
    } otherwise {
        my $error = shift;
        throw EBox::Exceptions::Internal($error);
    } finally {
        $self->enableZentyalModule();
    };
}

1;
