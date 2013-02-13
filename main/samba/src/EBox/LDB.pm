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

use Data::Dumper;
use File::Slurp;
use File::Temp qw(:seekable);
use Error qw( :try );
use Perl6::Junction qw(any);

use constant LDAPI => "ldapi://%2fopt%2fsamba4%2fprivate%2fldap_priv%2fldapi";

# NOTE: The list of attributes available in the different Windows Server versions
#       is documented in http://msdn.microsoft.com/en-us/library/cc223254.aspx
use constant ROOT_DSE_ATTRS => [
    'configurationNamingContext',
    'currentTime',
    'defaultNamingContext',
    'dnsHostName',
    'domainControllerFunctionality',
    'domainFunctionality',
    'dsServiceName',
    'forestFunctionality',
    'highestCommittedUSN',
    'isGlobalCatalogReady',
    'isSynchronized',
    'ldapServiceName',
    'namingContexts',
    'rootDomainNamingContext',
    'schemaNamingContext',
    'serverName',
    'subschemaSubentry',
    'supportedCapabilities',
    'supportedControl',
    'supportedLDAPPolicies',
    'supportedLDAPVersion',
    'supportedSASLMechanisms',
];

# Singleton variable
my $_instance = undef;

sub _new_instance
{
    my $class = shift;

    my $ignoredSidsFile = EBox::Config::etc() . 's4sync-sids.ignore';
    my @lines = read_file($ignoredSidsFile);
    my @sidsTmp = grep(/^\s*S-/, @lines);
    my @sids = map { s/\n//; $_; } @sidsTmp;

    my $self = {};
    $self->{ldb} = undef;
    $self->{idamp} = undef;
    $self->{ignoredSids} = \@sids;
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
                base => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS') {
            $self->clearConn();
            $reconnect = 1;
        }
    }

    if (not defined $self->{ldb} or $reconnect) {
        $self->{ldb} = $self->safeConnect();
    }

    return $self->{ldb};
}

sub safeConnect
{
    my ($self) = @_;

    my $retries = 6;
    my $ldb = undef;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to samba LDAP');
    };

    while (not $ldb = Net::LDAP->new(LDAPI) and $retries--) {
        my $samba = EBox::Global->modInstance('samba');
        unless ($samba->isRunning()) {
            EBox::debug("Samba daemon was stopped, starting it");
            $samba->_startService();
            sleep (5);
            next;
        }
        EBox::warn("Couldn't connect to samba LDAP server: $@, retrying");
        sleep (5);
    }

    unless ($ldb) {
        throw EBox::Exceptions::External(
            "FATAL: Couldn't connect to samba LDAP server");
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

# Method: existsDN
#
#   Finds whether a DN exists on the database
#
# Parameters:
#
#   dn   - dn to lookup
#   relativeToBaseDN - whether the given DN is relative to the baseDN (default: false)
#
# Returns:
#
#  boolean - whether the DN exists or not
#
# Exceptions:
#
#   Internal - If there is an error during the LDAP search
#
sub existsDN
{
    my ($self, $dn, $relativeToBaseDN) = @_;
    if ($relativeToBaseDN) {
        $dn = $dn . ','  . $self->dn();
    }

    my $ldb = $self->ldbCon();
    my %args = (base => $dn, scope=>'base', filter => '(objectclass=*)');
    my $result = $ldb->search(%args);

    if (ldap_error_name($result) eq 'LDAP_NO_SUCH_OBJECT') {
        # then it does not exists
        return 0;
    } else {
        # check if there is no other error
        $self->_errorOnLdap($result, \%args);
    }

    return $result->count() > 0;
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
}

sub ldapGroupsToLdb
{
    my ($self) = @_;

    EBox::info('Loading Zentyal groups into samba database');
    my $usersModule = EBox::Global->modInstance('users');
    my $groups = $usersModule->groups();
    foreach my $group (@{$groups}) {
        my $dn = $group->dn();
        EBox::debug("Loading group $dn");
        my $sambaGroup = undef;
        try {
            my $samAccountName = $group->get('cn');
            my $params = {
                gidNumber => scalar ($group->get('gidNumber')),
                description => scalar ($group->get('description')),
            };
            $sambaGroup = EBox::Samba::Group->create($samAccountName, $params);
        } otherwise {
            my $error = shift;
            EBox::error("Error loading group '$dn': $error");
        };
        next unless defined $sambaGroup;

        foreach my $user (@{$group->users()}) {
            try {
                my $smbUser = new EBox::Samba::User(samAccountName => $user->get('uid'));
                next unless defined $smbUser;
                $sambaGroup->addMember($smbUser, 1);
            } otherwise {
                my $error = shift;
                EBox::error("Error adding member: $error");
            };
        }
        $sambaGroup->save();
    }
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
                # If the user does not exists the module has not been enabled yet
                next unless ($user->exists());

                EBox::info("Importing service principal $dn");
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
                    EBox::info("Adding SPN '$spn' to user " . $smbUser->dn());
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
        base => $self->dn(),
        scope => 'sub',
        filter => '(&(&(objectclass=user)(!(objectclass=computer)))' .
                  '(!(showInAdvancedViewOnly=*))(!(isDeleted=*)))',
        attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('samAccountName')) {
        my $user = new EBox::Samba::User(entry => $entry);
        my $entrySid = $user->sid();

        my $skip = 0;
        foreach my $ignoredSidMask (@{$self->{ignoredSids}}) {
            $skip = 1 if ($user->sid() =~ m/$ignoredSidMask/);
        }
        next if $skip;

        push (@{$list}, $user);
    }
    return $list;
}

sub groups
{
    my ($self) = @_;

    my $params = {
        base => $self->dn(),
        scope => 'sub',
        filter => '(&(objectclass=group)(!(showInAdvancedViewOnly=*))(!(isDeleted=*)))',
        attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('samAccountName')) {
        my $group = new EBox::Samba::Group(entry => $entry);

        my $skip = 0;
        foreach my $ignoredSidMask (@{$self->{ignoredSids}}) {
            $skip = 1 if ($group->sid() =~ m/$ignoredSidMask/);
        }
        my $entrySid = $group->sid();
        next if $skip;

        push (@{$list}, $group);
    }
    return $list;
}

# Method: dnsZones
#
#   Returns the DNS zones stored in the samba LDB. As this is called
#   from DNS module it should be able to read the zones even when samba
#   daemon is stopped, so we use ldbsearch to read the ldb files directly.
#
sub dnsZones
{
    my ($self) = @_;

    my @zonePrefixes = (
        "CN=MicrosoftDNS,DC=DomainDnsZones",
        "CN=MicrosoftDNS,DC=ForestDnsZones",
        "CN=MicrosoftDNS,CN=System");
    my @ignoreZones = ('RootDNSServers', '..TrustAnchors');
    my $zones = [];

    my $sambaModule = EBox::Global->modInstance('samba');
    my $private = $sambaModule->PRIVATE_DIR();
    my $samdb = "$private/sam.ldb";
    if (EBox::Sudo::fileTest('-f', $samdb)) {
        my $tmp = File::Temp->new(TEMPLATE => 'ldbsearch.XXXXX',
                                  DIR => EBox::Config::tmp(),
                                  UNLINK => 1,
                                  SUFFIX => '.ldif');

        my $cmd = "ldbsearch -H $samdb -d0 -s base -b '' defaultNamingContext";
        my $out = EBox::Sudo::root($cmd);
        $tmp->seek(0, SEEK_SET);
        write_file($tmp->filename(), $out);
        my $ldif = new Net::LDAP::LDIF($tmp->filename());
        my $entry = $ldif->read_entry();
        my $base = $entry->get_value('defaultNamingContext');

        for my $prefix (@zonePrefixes) {
            $cmd = "ldbsearch -H $samdb -d0 -s sub -b '$prefix,$base' '(objectClass=dnsZone)' name";
            $out = EBox::Sudo::root($cmd);
            $tmp->seek(0, SEEK_SET);
            write_file($tmp->filename(), $out);
            $ldif = new Net::LDAP::LDIF($tmp->filename());
            while (not $ldif->eof()) {
                $entry = $ldif->read_entry();
                my $name = $entry->get_value('name');
                next unless defined $name;
                next if $name eq any @ignoreZones;
                push (@{$zones}, lc ($name));
            }
        }
    }
    return $zones;
}

# Method: rootDse
#
#   Returns the root DSE
#
sub rootDse
{
    my ($self) = @_;

    return $self->ldbCon()->root_dse(attrs => ROOT_DSE_ATTRS);
}

1;
