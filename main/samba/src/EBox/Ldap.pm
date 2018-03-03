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

use EBox::Samba::OU;
use EBox::Samba::Contact;
use EBox::Samba::DNS::Zone;
use EBox::Samba::User;

use EBox::Samba::IdMapDb;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_name ldap_explode_dn);

use TryCatch;
use File::Slurp qw(read_file);
use File::Temp;
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
#   object of class <EBox::Ldap>
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
        $self->{idmap} = EBox::Samba::IdMapDb->new();
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

    unless ($self->{dn}) {
        my $users = EBox::Global->modInstance('samba');
        unless ($users->isProvisioned()) {
            throw EBox::Exceptions::Internal('Samba is not yet provisioned');
        }

        my $tmp = new File::Temp(DIR => EBox::Config::tmp(),
                                 TEMPLATE => 'dnsZonesXXXXXX',
                                 SUFFIX => '.ldif');
        $tmp->unlink_on_destroy(1);
        my $ldifFile = $tmp->filename();

        my $cmd = "ldbsearch -H /var/lib/samba/private/sam.ldb " .
                  "-s base 'dn' " .
                  "--debug-stderr 2>/dev/null 1>$ldifFile";
        EBox::Sudo::root($cmd);

        my $dn = undef;
        my $ldif = new Net::LDAP::LDIF($ldifFile, 'r', onerror => 'undef');
        while (not $ldif->eof()) {
            my $entry = $ldif->read_entry();
            if ($ldif->error() or not defined $entry) {
                throw EBox::Exceptions::Internal(
                __x('Error loading LDIF. Error message: {x}, Error lines: {y}',
                    x => $ldif->error(), y => $ldif->error_lines()));
            } else {
                $dn = $entry->dn();
            }
        }
        $ldif->done();

        if (defined $dn and length $dn) {
            $self->{dn} = $dn;
        } else {
            throw EBox::Exceptions::External('Cannot get LDAP dn');
        }
    }

    return $self->{dn};
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

    my $realm = EBox::Global->modInstance('samba')->kerberosRealm();
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

# Method: ldapConf
#
#   Returns the current configuration for LDAP: 'dn', 'ldap', 'port'
#
# Returns:
#
#   hash ref  - holding the keys 'dn', 'ldap', and 'port'
#
sub ldapConf
{
    my ($self) = @_;

    my $conf = {
        'dn'     => $self->dn(),
        'ldap'   => LDAP,
        'port' => 389,
    };

    return $conf;
}

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

    return "uid=$user," . EBox::Samba::User::defaultContainer()->dn();
}

sub users
{
    my ($self, $system) = @_;

    # TODO Remove this method
    EBox::warn("EBox::Ldap::users to be deprecated");
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('samba');
    return $samba->users();
}

sub contacts
{
    my ($self) = @_;

    # TODO Remove this method
    EBox::warn("EBox::Ldap::contacts to be deprecated");
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('contacts');
    return $samba->contacts();
}

sub groups
{
    my ($self) = @_;

    # TODO Remove this method
    EBox::warn("EBox::Ldap::groups to be deprecated");
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('samba');
    return $samba->groups();
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

    # TODO Remove this method
    EBox::warn("EBox::Ldap::securityGroups to be deprecated");
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('samba');
    return $samba->securityGroups();
}

# Method: ous
#
#   Return OUs in samba LDB. It is guaranteed that OUs are returned in a
#   hierarquical way, parents before childs.
#
sub ous
{
    my ($self, $baseDN) = @_;

    # TODO Remove this method
    EBox::warn("EBox::Ldap::ous to be deprecated");
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('samba');
    return $samba->ous($baseDN);
}

# Method: dnsZones
#
#   Returns the DNS zones stored in the samba LDB
#
sub dnsZones
{
    my ($self) = @_;

    unless (EBox::Global->modInstance('samba')->isProvisioned()) {
        return [];
    }

    my $defaultNC = $self->dn();
    my @zonePrefixes = (
        "CN=MicrosoftDNS,DC=DomainDnsZones,$defaultNC",
        "CN=MicrosoftDNS,DC=ForestDnsZones,$defaultNC",
        "CN=MicrosoftDNS,CN=System,$defaultNC");
    my @ignoreZones = ('RootDNSServers', '..TrustAnchors', '..InProgress');
    my $zones = [];

    foreach my $prefix (@zonePrefixes) {
        my $tmp = new File::Temp(DIR => EBox::Config::tmp(),
                                 TEMPLATE => 'dnsZonesXXXXXX',
                                 SUFFIX => '.ldif');
        $tmp->unlink_on_destroy(1);
        my $ldifFile = $tmp->filename();
        my $cmd = "ldbsearch -H /var/lib/samba/private/sam.ldb -s one " .
                  "-b '$prefix' '(objectClass=dnsZone)' " .
                  "--debug-stderr 2>/dev/null 1>$ldifFile";
        EBox::Sudo::root($cmd);

        my $ldif = new Net::LDAP::LDIF($ldifFile, 'r', onerror => 'undef');
        while (not $ldif->eof()) {
            my $entry = $ldif->read_entry();
            if ($ldif->error() or not defined $entry and not $ldif->eof()) {
                throw EBox::Exceptions::Internal(
                __x('Error loading LDIF. Error message: {x}, Error lines: {y}',
                    x => $ldif->error(), y => $ldif->error_lines()));
            } elsif (not defined $entry and $ldif->eof()) {
                # This is an empty LDIF, skip
            } else {
                my $name = $entry->get_value('name');
                next unless defined $name and length $name;

                my $skip = 0;
                foreach my $skipPrefix (@ignoreZones) {
                    $skip = 1 if ($name =~ m/^$skipPrefix/);
                }

                unless ($skip) {
                    my $zone = new EBox::Samba::DNS::Zone(entry => $entry);
                    push (@{$zones}, $zone);
                }
            }
        }
        $ldif->done();
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

# Method: domainAdminsGroup
#
#   Return the "Domain Admins" group
#
sub domainAdminsGroup
{
    my ($self) = @_;

    my $domainSid = $self->domainSID();
    my $sid = "$domainSid-512";
    my $obj = new EBox::Samba::Group(sid => $sid);
    return $obj;
}

# Method: domainUsersGroup
#
#   Return the domain users group
#
sub domainUsersGroup
{
    my ($self) = @_;

    my $domainSid = $self->domainSID();
    my $sid = "$domainSid-513";
    my $obj = new EBox::Samba::Group(sid => $sid);
    return $obj;
}

# Method: domainGuestsGroup
#
#   Return the domain guests group
#
sub domainGuestsGroup
{
    my ($self) = @_;

    my $domainSid = $self->domainSID();
    my $sid = "$domainSid-514";
    my $obj = new EBox::Samba::Group(sid => $sid);
    return $obj;
}

# Method: domainAdminUser
#
#   Return the domain admin user
#
sub domainAdminUser
{
    my ($self) = @_;

    my $domainSid = $self->domainSID();
    my $sid = "$domainSid-500";
    my $obj = new EBox::Samba::User(sid => 500);
    return $obj;
}

# Method: domainGuestUser
#
#   Return the domain guest user
#
sub domainGuestUser
{
    my ($self) = @_;

    my $domainSid = $self->domainSID();
    my $sid = "$domainSid-501";
    my $obj = new EBox::Samba::User(sid => $sid);
    return $obj;
}

1;
