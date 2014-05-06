# Copyright (C) 2012-2014 Zentyal S.L.
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

package EBox::Ldap;
use base 'EBox::LDAPBase';

use EBox::Users::OU;
use EBox::Users::Contact;
use EBox::Samba::DNS::Zone;
use EBox::Users::User;

use EBox::LDB::IdMapDb;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_name ldap_explode_dn);

use TryCatch::Lite;
use File::Slurp qw(read_file);
use Perl6::Junction qw(any);
use Time::HiRes;

use constant LDAPI => "ldapi://%2fvar%2flib%2fsamba%2fprivate%2fldap_priv%2fldapi" ;
use constant LDAP  => "ldap://127.0.0.1";

# The LDB containers that will be ignored when quering for users stored in LDB
use constant QUERY_IGNORE_CONTAINERS => (
    'Microsoft Exchange System Objects',
);

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

    my $self = $class->SUPER::_new_instance();
    $self->{idamp} = undef;
    bless ($self, $class);
    return $self;
}

# Method: instance
#
#   Return a singleton instance of this class
#
# Returns:
#
#   object of class <EBox::LDB>
sub instance
{
    my ($class) = @_;

    unless(defined($_instance)) {
        $_instance = $class->_new_instance();
    }

    return $_instance;
}

sub connected
{
    my ($self) = @_;
    if ($self->{ldap}) {
        # Workaround to detect if connection is broken and force reconnection
        my $mesg = $self->{ldap}->search(
                base   => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS' ) {
            $self->{ldap}->unbind;
            return 0;
        }

        return 1;
    }

    return 0;
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

# Method: connection
#
#   Return the Net::LDAP connection used by the module
#
# Exceptions:
#
#   Internal - If connection can't be created
#
# Override:
#   EBox::LDAPBase::connection
#
sub connection
{
    my ($self) = @_;

    # Workaround to detect if connection is broken and force reconnection
    my $reconnect = 0;
    if (defined $self->{ldap}) {
        my $mesg = $self->{ldap}->search(
                base => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS') {
            $self->clearConn();
            $reconnect = 1;
        }
    }

    if (not defined $self->{ldap} or $reconnect) {
        $self->{ldap} = $self->safeConnect();
    }

    return $self->{ldap};
}

# Method: url
#
#  Return the URL or parameter to create a connection with this LDAP
#
# Override: EBox::LDAPBase::url
#
sub url
{
    return LDAPI;
}

sub safeConnect
{
    my ($self) = @_;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to samba LDAP');
    };

    my $error = undef;
    my $lastError = undef;
    my $maxTries = 300;
    for (my $try = 1; $try <= $maxTries; $try++) {
        my $ldb = Net::LDAP->new(LDAPI);
        if (defined $ldb) {
            my $dse = $ldb->root_dse(attrs => ROOT_DSE_ATTRS);
            if (defined $dse) {
                if ($try > 1) {
                    EBox::info("Connection to Samba LDB successful after $try tries.");
                }
                return $ldb;
            }
        }
        $error = $@;
        EBox::warn("Could not connect to Samba LDB: $error, retrying. ($try attempts)") if (($try == 1) or (($try % 100) == 0));
        Time::HiRes::sleep(0.1);
    }

    throw EBox::Exceptions::External(
        __x(q|FATAL: Could not connect to samba LDAP server: {error}|,
            error => $error));
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

    if ((defined $self->{dn}) and length ($self->{dn})) {
        return $self->{dn};
    }

    my $output = EBox::Sudo::root("ldbsearch -H /var/lib/samba/private/sam.ldb -s base -b '' -d0 | grep -v ^GENSEC");
    my $ldifBuffer = join ('', @{$output});
    EBox::debug($ldifBuffer);

    my $fd;
    open $fd, '<', \$ldifBuffer;

    my $ldif = Net::LDAP::LDIF->new($fd);
    if (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        if ($ldif->error()) {
            EBox::debug("Error msg: " . $ldif->error());
            EBox::debug("Error lines:\n" . $ldif->error_lines());
        } elsif (not $ldif->eof()) {
            EBox::debug("Got more than one entry!");
        } elsif ($entry) {
            $self->{dn} = $entry->get_value('defaultNamingContext');
        } else {
            EBox::debug("Got an empty entry");
        }
    }
    $ldif->done();
    close $fd;

    return defined $self->{dn} ? $self->{dn} : '';
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
        # The object is not a SecurityPrincipal but a SamDomainBase. As we only query
        # for the sid, it works.
        my $object = new EBox::Samba::SecurityPrincipal(entry => $entry);
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

# Method: rootDn
#
#       Returns the dn of the priviliged user
#
# Returns:
#
#       string - eboxdn
#
sub rootDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->dn();
    }
    return 'cn=zentyal,' . $dn;
}

# Method: roRootDn
#
#       Returns the dn of the read only priviliged user
#
# Returns:
#
#       string - the Dn
#
sub roRootDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->dn();
    }
    return 'cn=zentyalro,' . $dn;
}

# Method: ldapConf
#
#       Returns the current configuration for LDAP: 'dn', 'ldapi', 'rootdn'
#
# Returns:
#
#     hash ref  - holding the keys 'dn', 'ldap', and 'rootdn'
#
sub ldapConf
{
    my ($self) = @_;

    my $conf = {
        'dn'     => $self->dn(),
        'ldap'   => LDAP,
        'port' => 389,
        'rootdn' => $self->rootDn(),
    };
    return $conf;
}


# FIXME
#sub ldapUsersToLdb
#{
#    my ($self) = @_;
#
#    EBox::info('Loading Zentyal users into samba database');
#    my $global = EBox::Global->getInstance();
#    my $usersMod = $global->modInstance('users');
#    my $sambaMod = $global->modInstance('samba');
#
#    my $users = $usersMod->users();
#    foreach my $user (@{$users}) {
#        my $parent = $sambaMod->ldbObjectFromLDAPObject($user->parent);
#        if (not $parent) {
#            my $dn = $user->dn();
#            throw EBox::Exceptions::External("Unable to to find the container for '$dn' in Samba");
#        }
#        my $samAccountName = $user->get('uid');
#        EBox::debug("Loading user $samAccountName");
#        try {
#            my %args = (
#                name           => scalar ($user->get('cn')),
#                samAccountName => scalar ($samAccountName),
#                parent         => $parent,
#                uidNumber      => scalar ($user->get('uidNumber')),
#                sn             => scalar ($user->get('sn')),
#                givenName      => scalar ($user->get('givenName')),
#                description    => scalar ($user->get('description')),
#                kerberosKeys   => $user->kerberosKeys(),
#            );
#            my $sambaUser = EBox::Samba::User->create(%args);
#            $sambaUser->_linkWithUsersObject($user);
#            unless ($user->isDisabled()) {
#                $sambaUser->setAccountEnabled(1);
#            }
#        } catch (EBox::Exceptions::DataExists $e) {
#            EBox::debug("User $samAccountName already in Samba database");
#            my $sambaUser = new EBox::Samba::User(samAccountName => $samAccountName);
#            $sambaUser->setCredentials($user->kerberosKeys());
#            EBox::debug("Password updated for user $samAccountName");
#        } catch ($error) {
#            EBox::error("Error loading user '$samAccountName': $error");
#        }
#    }
#}
#
#sub ldapContactsToLdb
#{
#    my ($self) = @_;
#
#    EBox::info('Loading Zentyal contacts into samba database');
#    my $global = EBox::Global->getInstance();
#    my $usersMod = $global->modInstance('users');
#    my $sambaMod = $global->modInstance('samba');
#
#    my $contacts = $usersMod->contacts();
#    foreach my $contact (@{$contacts}) {
#        my $parent = $sambaMod->ldbObjectFromLDAPObject($contact->parent);
#        if (not $parent) {
#            my $dn = $contact->dn();
#            throw EBox::Exceptions::External("Unable to to find the container for '$dn' in Samba");
#        }
#
#        my $parentDN = $parent->dn();
#        my $name = $contact->get('cn');
#        EBox::debug("Loading contact $name on $parentDN");
#        try {
#            my %args = (
#                name        => scalar ($name),
#                parent      => $parent,
#                givenName   => scalar ($contact->get('givenName')),
#                initials    => scalar ($contact->get('initials')),
#                sn          => scalar ($contact->get('sn')),
#                displayName => scalar ($contact->get('displayName')),
#                description => scalar ($contact->get('description')),
#                mail        => $contact->get('mail')
#            );
#            my $sambaContact = EBox::Samba::Contact->create(%args);
#            $sambaContact->_linkWithUsersObject($contact);
#        } catch (EBox::Exceptions::DataExists $e) {
#            EBox::debug("Contact $name already in $parentDN on Samba database");
#        } catch ($error) {
#            EBox::error("Error loading contact '$name' in '$parentDN': $error");
#        }
#    }
#}
#
#sub ldapGroupsToLdb
#{
#    my ($self) = @_;
#
#    EBox::info('Loading Zentyal groups into samba database');
#    my $global = EBox::Global->getInstance();
#    my $usersMod = $global->modInstance('users');
#    my $sambaMod = $global->modInstance('samba');
#
#    my $groups = $usersMod->groups();
#    foreach my $group (@{$groups}) {
#        my $parent = $sambaMod->ldbObjectFromLDAPObject($group->parent);
#        if (not $parent) {
#            my $dn = $group->dn();
#            throw EBox::Exceptions::External("Unable to to find the container for '$dn' in Samba");
#        }
#        my $parentDN = $parent->dn();
#        my $name = $group->get('cn');
#        EBox::debug("Loading group $name");
#        my $sambaGroup = undef;
#        try {
#            my %args = (
#                name => $name,
#                parent => $parent,
#                description => scalar ($group->get('description')),
#                isSecurityGroup => $group->isSecurityGroup(),
#            );
#            if ($group->isSecurityGroup()) {
#                $args{gidNumber} = scalar ($group->get('gidNumber'));
#            };
#            $sambaGroup = EBox::Samba::Group->create(%args);
#            $sambaGroup->_linkWithUsersObject($group);
#        } catch (EBox::Exceptions::DataExists $e) {
#            EBox::debug("Group $name already in Samba database");
#        } catch ($e) {
#            EBox::error("Error loading group '$name': $e");
#        }
#        next unless defined $sambaGroup;
#
#        foreach my $member (@{$group->members()}) {
#            try {
#                my $smbMember = $sambaMod->ldbObjectFromLDAPObject($member);
#                next unless ($smbMember);
#                $sambaGroup->addMember($smbMember, 1);
#            } catch ($error) {
#                EBox::error("Error adding member: $error");
#            }
#        }
#        $sambaGroup->save();
#    }
#}
#
## Method: ldapServicePrincipalsToLdb
##
##   This method import the zentyal module service principals to LDB. The only
##   modules that create them are mail and proxy:
##       mail  - IMAP/zentyal.zentyal-domain.lan
##               POP3/zentyal.zentyal-domain.lan
##               SMTP/zentyal.zentyal-domain.lan
##       proxy - HTTP/zentyal.zentyal-domain.lan
##
##   The behaviour here is tricky because Heimdal does not support principal
##   aliases. In LDAP a principal is created for each SPN, but in
##   LDB an account {module}-{hostname} is created and all SPNs are added to it.
##   For example, the mail account create three principal accounts in LDAP
##   under the Kerberos OU (IMAP, POP3 and SMTP). When imported to LDB, an
##   account mail-{hostname} is created and the three SPNs are added to this
##   account.
##
##   The three different principal accounts in LDAP are linked to the same
##   account in the SAM database.
##
#sub ldapServicePrincipalsToLdb
#{
#    my ($self) = @_;
#
#    EBox::info('Loading Zentyal service principals into samba database');
#    my $sysinfo = EBox::Global->modInstance('sysinfo');
#    my $hostname = $sysinfo->hostName();
#    my $fqdn = $sysinfo->fqdn();
#
#    my $modules = EBox::Global->modInstancesOfType('EBox::KerberosModule');
#    my $usersMod = EBox::Global->modInstance('users');
#    my $sambaMod = EBox::Global->modInstance('samba');
#
#    my $ldb = $sambaMod->ldb();
#    my $baseDn = $usersMod->ldap()->dn();
#    my $realm = $usersMod->kerberosRealm();
#    my $ldapKerberosDN = "ou=Kerberos,$baseDn";
#    my $ldapKerberosOU = new EBox::Users::OU(dn => $ldapKerberosDN);
#
#    # If OpenLDAP doesn't have the Kerberos OU, we don't need to do anything.
#    return unless ($ldapKerberosOU and $ldapKerberosOU->exists());
#
#    # At this point, the OU must has been created and linked in LDB
#    my $ldbKerberosOU = $sambaMod->ldbObjectFromLDAPObject($ldapKerberosOU);
#    unless ($ldbKerberosOU and $ldbKerberosOU->exists()) {
#        throw EBox::Exceptions::Internal("Kerberos OU not found in LDB.");
#    }
#
#    foreach my $module (@{$modules}) {
#        my $principals = $module->kerberosServicePrincipals();
#        my $samAccountName = "$principals->{service}-$hostname";
#        try {
#            # First step, create the account
#            my $smbUser = new EBox::Samba::User(samAccountName => $samAccountName);
#            unless ($smbUser->exists()) {
#                # Get the heimdal user to extract the kerberos keys. All service
#                # principals for each module should have the same keys, so take
#                # the first one.
#                my $p = @{$principals->{principals}}[0];
#                my $dn = "krb5PrincipalName=$p/$fqdn\@$realm,$ldapKerberosDN";
#                my $user = new EBox::Users::User(dn => $dn, internal => 1);
#                # If the user does not exists the module has not been enabled yet
#                next unless ($user->exists());
#
#                EBox::info("Importing service principal $dn");
#                my %args = (
#                    name           => $samAccountName,
#                    parent         => $ldbKerberosOU,
#                    samAccountName => $samAccountName,
#                    kerberosKeys   => $user->kerberosKeys(),
#                );
#                if (length $user->get('description')) {
#                    $args{description} = $user->get('description');
#                }
#                $smbUser = EBox::Samba::User->create(%args);
#                $smbUser->setCritical(1);
#                $smbUser->setInAdvancedViewOnly(1);
#            }
#            # Second step, add the SPNs to the samba account
#            foreach my $p (@{$principals->{principals}}) {
#                try {
#                    my $spn = "$p/$fqdn";
#                    EBox::info("Adding SPN '$spn' to user " . $smbUser->dn());
#                    $smbUser->addSpn($spn);
#                } catch ($error) {
#                    EBox::error("Error adding SPN '$p' to account '$samAccountName': $error");
#                }
#            }
#            # Third step, map LDAP principals to the same samba user
#            foreach my $p (@{$principals->{principals}}) {
#                my $dn = "krb5PrincipalName=$p/$fqdn\@$realm,$ldapKerberosDN";
#                my $user = new EBox::Users::User(dn => $dn, internal => 1);
#                $smbUser->_linkWithUsersObject($user);
#            }
#        } catch ($error) {
#            EBox::error("Error adding account '$samAccountName': $error");
#        }
#    }
#}

# Method: userBindDN
#
#  given a plain user name, it return the argument needed to bind to the
#  directory which that user, normally a DN
#
# Parametes:
#        user - plain username
#
# Returns:
#   DN or other token to use for binding to the directory
sub userBindDN
{
    my ($self, $user) = @_;

    return "uid=$user," . EBox::Users::User::defaultContainer()->dn();
}

sub users
{
    my ($self, %params) = @_;

    my $list = [];

    # Query the containers stored in the root DN and skip the ignored ones
    # Note that 'OrganizationalUnit' and 'msExchSystemObjectsContainer' are
    # subclasses of 'Container'.
    my @containers;
    my $params = {
        base => $self->dn(),
        scope => 'one',
        filter => '(|(objectClass=Container)(objectClass=OrganizationalUnit)(objectClass=msExchSystemObjectsContainer))',
        attrs => ['*'],
    };
    my $result = $self->search($params);
    foreach my $entry ($result->sorted('cn')) {
        my $container = new EBox::Users::Container(entry => $entry);
        next if $container->get('cn') eq any QUERY_IGNORE_CONTAINERS;
        push (@containers, $container);
    }

    # Query the users stored in the non ignored containers
    my $spFilter = $params{servicePrincipals} ? '' : '(!(servicePrincipalName=*))';
    my $filter = "(&(&(objectclass=user)(!(objectclass=computer)))(!(isDeleted=*))$spFilter)";
    foreach my $container (@containers) {
        $params = {
            base   => $container->dn(),
            scope  => 'sub',
            filter => $filter,
            attrs  => ['*', 'unicodePwd', 'supplementalCredentials'],
        };
        $result = $self->search($params);
        foreach my $entry ($result->sorted('samAccountName')) {
            my $user = new EBox::Samba::User(entry => $entry);
            push (@{$list}, $user);
        }
    }

    return $list;
}

sub contacts
{
    my ($self) = @_;

    my $params = {
        base => $self->dn(),
        scope => 'sub',
        filter => '(&(objectclass=contact)(!(isDeleted=*)))',
        attrs => ['*'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('name')) {
        my $contact = new EBox::Users::Contact(entry => $entry);

        push (@{$list}, $contact);
    }
    return $list;
}

sub groups
{
    my ($self) = @_;

    my $params = {
        base => $self->dn(),
        scope => 'sub',
        filter => '(&(objectclass=group)(!(isDeleted=*)))',
        attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
    };
    my $result = $self->search($params);
    my $list = [];
    foreach my $entry ($result->sorted('samAccountName')) {
        #my $group = new EBox::Samba::Group(entry => $entry);
        my $group = new EBox::Users::Group(entry => $entry);
        push (@{$list}, $group);
    }

    return $list;
}

# Method: securityGroups
#
#   Returns an array containing all the security groups
#
# Returns:
#
#    array - holding the groups as EBox::Samba::Group objects
#
sub securityGroups
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $sambaMod = $global->modInstance('samba');
    if ((not $sambaMod->isEnabled()) or (not $sambaMod->isProvisioned())) {
        return [];
    }

    my $allGroups = $self->groups();
    my @securityGroups = ();
    foreach my $group (@{$allGroups}) {
        if ($group->isSecurityGroup()) {
            push (@securityGroups, $group);
        }
    }
    # sort grups by name
    @securityGroups = sort {
        my $aValue = $a->name();
        my $bValue = $b->name();
        (lc $aValue cmp lc $bValue) or
            ($aValue cmp $bValue)
    } @securityGroups;

    return \@securityGroups;
}

# Method: ous
#
#   Return OUs in samba LDB. It is guaranteed that OUs are returned in a
#   hierarquical way, parents before childs.
#
sub ous
{
    my ($self, $baseDN) = @_;

    unless (defined $baseDN) {
        $baseDN = $self->dn();
    }

    my $objectClass = EBox::Samba::OU->mainObjectClass();
    my $args = {
        base => $baseDN,
        filter => "(objectclass=$objectClass)",
        scope => 'one',
    };

    my $ous = [];
    my $result = $self->search($args);
    foreach my $entry ($result->entries()) {
        my $ou = EBox::Samba::OU->new(entry => $entry);
        push (@{$ous}, $ou);
        my $nested = $self->ous($ou->dn());
        push (@{$ous}, @{$nested});
    }

    return $ous;
}

# Method: dnsZones
#
#   Returns the DNS zones stored in the samba LDB
#
sub dnsZones
{
    my ($self) = @_;

    my $defaultNC = $self->dn();
    my @zonePrefixes = (
        "CN=MicrosoftDNS,DC=DomainDnsZones,$defaultNC",
        "CN=MicrosoftDNS,DC=ForestDnsZones,$defaultNC",
        "CN=MicrosoftDNS,CN=System,$defaultNC");
    my @ignoreZones = ('RootDNSServers', '..TrustAnchors');
    my $zones = [];

    foreach my $prefix (@zonePrefixes) {
        my $output = EBox::Sudo::root(
            "ldbsearch -H /var/lib/samba/private/sam.ldb -s one -b '$prefix' '(objectClass=dnsZone)' -d0 | grep -v ^GENSEC");
        my $ldifBuffer = join ('', @{$output});
        EBox::debug($ldifBuffer);

        my $fd;
        open $fd, '<', \$ldifBuffer;

        my $ldif = Net::LDAP::LDIF->new($fd);
        while (not $ldif->eof()) {
            my $entry = $ldif->read_entry();
            if ($ldif->error()) {
                EBox::debug("Error msg: " . $ldif->error());
                EBox::debug("Error lines:\n" . $ldif->error_lines());
            } elsif ($entry) {
                my $name = $entry->get_value('name');
                next unless defined $name;
                next if $name eq any @ignoreZones;
                my $zone = new EBox::Samba::DNS::Zone(entry => $entry);
                push (@{$zones}, $zone);
            } else {
                EBox::debug("Got an empty entry");
            }
        }
        $ldif->done();
        close $fd
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

    return $self->connection()->root_dse(attrs => ROOT_DSE_ATTRS);
}

# FIXME
sub changeUserPassword
{
    my ($self, $dn, $newPasswd, $oldPasswd) = @_;

    $self->connection();
    my $rootdse = $self->{ldap}->root_dse();
    if ($rootdse->supported_extension('1.3.6.1.4.1.4203.1.11.1')) {
        # Update the password using the LDAP extension will update the kerberos keys also
        # if the smbk5pwd module and its overlay are loaded
        require Net::LDAP::Extension::SetPassword;
        my $mesg = $self->{ldap}->set_password(user => $dn,
                                               oldpasswd => $oldPasswd,
                                               newpasswd => $newPasswd);
        $self->_errorOnLdap($mesg, $dn);
    } else {
        my $mesg = $self->{ldap}->modify( $dn,
                        changes => [ delete => [ userPassword => $oldPasswd ],
                        add     => [ userPassword => $newPasswd ] ]);
        $self->_errorOnLdap($mesg, $dn);
    }
}

1;
