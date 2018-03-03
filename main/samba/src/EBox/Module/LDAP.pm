# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Module::LDAP;
use base qw(EBox::Module::Service);

use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::LDAP;

use EBox::Samba::FSMO;
use EBox::Samba::AuthKrbHelper;
use EBox::Samba::LdapObject;
use Net::LDAP;
use Net::LDAP::Util qw(ldap_explode_dn canonical_dn);
use Net::LDAP::LDIF;
use Net::DNS::Resolver;
use File::Temp;
use File::Slurp;
use Authen::SASL;

use TryCatch;

# Method: _ldapModImplementation
#
#   All modules using any of the functions in LdapUserBase.pm
#   should override this method to return the implementation
#   of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
#
sub _ldapModImplementation
{
    throw EBox::Exceptions::NotImplemented('_ldapModImplementation', __PACKAGE__);
}

# Method: ldap
#
#   Provides an EBox::Ldap object with the proper configuration for the
#   LDAP setup of this ebox
#
sub ldap
{
    my ($self) = @_;

    unless (defined($self->{ldap})) {
        $self->{ldap} = $self->global()->modInstance('samba')->newLDAP();
    }
    return $self->{ldap};
}

sub clearLdapConn
{
    my ($self) = @_;
    $self->{ldap} or return;
    $self->{ldap}->clearConn();
    $self->{ldap} = undef;
}

# Method: _dnsResolve
#
#   Resolve a DNS name to its IP addresses
#
# Returns:
#
#   array ref - Containing the resolved IP addresses
#
sub _dnsResolve
{
    my ($self, $dnsName) = @_;

    unless (defined $dnsName and length $dnsName) {
        throw EBox::Exceptions::MissingArgument('dnsName');
    }

    my $addresses = [];
    my $resolver = new Net::DNS::Resolver(config_file => '/etc/resolv.conf');
    my $reply = $resolver->search($dnsName);
    if ($reply) {
        foreach my $rr ($reply->answer()) {
            next unless $rr->type() eq 'A';
            push (@{$addresses}, $rr->address());
        }
    } else {
        my $resolvConf = read_file('/etc/resolv.conf');
        throw EBox::Exceptions::Internal(
            __x("DNS query failed: {x} (using nameservers {y}, " .
                "/etc/resolv.conf was\n'{z}'",
                x => $resolver->errorstring(),
                y => join(', ', $resolver->nameservers()),
                z => $resolvConf));
    }

    my $ipsString = join (', ', @{$addresses});
    my $nsString = join (', ', $resolver->nameservers());
    EBox::debug("Name '$dnsName' has been resolved to the following " .
                "IP addresses [$ipsString], using name servers [$nsString]");

    unless (scalar @{$addresses}) {
        throw EBox::Exceptions::Internal("Name '$dnsName' could not have ".
            "been resolved using nameservers [$nsString]");
    }

    return $addresses;
}

sub _connectToSchemaMaster
{
    my ($self) = @_;

    my $fsmo = new EBox::Samba::FSMO();
    my $ntdsOwner = $fsmo->getSchemaMaster();
    my $ntdsParts = ldap_explode_dn($ntdsOwner);
    shift @{$ntdsParts};
    my $serverOwner = canonical_dn($ntdsParts);
    EBox::debug("Schema master FSMO role owner is $serverOwner");

    my $params = {
        base => $serverOwner,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['dnsHostName'],
    };
    my $result = $self->ldap->search($params);
    if ($result->count() != 1) {
        throw EBox::Exceptions::Internal(
            __x("Error on search: Expected one entry, got {x}.\n",
                x => $result->count()));
    }
    my $entry = $result->entry(0);
    my $dnsOwner = $entry->get_value('dnsHostName');
    EBox::debug("Schema master FSMO role owner name is $dnsOwner");

    EBox::debug("Resolving schema master DNS name $dnsOwner");
    my $ownerAddresses = $self->_dnsResolve($dnsOwner);

    my $masterLdap = new Net::LDAP($ownerAddresses);
    unless ($masterLdap) {
        throw EBox::Exceptions::Internal(
            __x('Error connecting to schema master role owner ({x})',
                x => $dnsOwner));
    }
    my $socket = $masterLdap->socket();
    my $connectedIp = '';
    if ($socket->isa('IO::Socket::INET6') or $socket->isa('IO::Socket::INET')) {
        $connectedIp = $socket->sockhost();
    }
    my $connectedPort = $masterLdap->port();
    EBox::debug("Connected to schema master: $connectedIp:$connectedPort");

    # Bind with schema operator privilege
    my $krbHelper = new EBox::Samba::AuthKrbHelper(RID => 500);
    my $sasl = new Authen::SASL(mechanism => 'GSSAPI');
    unless ($sasl) {
        throw EBox::Exceptions::External(
            __x("Unable to setup SASL object: {x}",
                x => $@));
    }
    # Workaround for hostname canonicalization
    my $saslClient = $sasl->client_new('ldap', $dnsOwner);
    unless ($saslClient) {
        throw EBox::Exceptions::External(
            __x("Unable to create SASL client: {x}",
                x => $@));
    }

    # Check GSSAPI support
    my $dse = $masterLdap->root_dse(attrs => ['defaultNamingContext', '*']);
    unless ($dse->supported_sasl_mechanism('GSSAPI')) {
        throw EBox::Exceptions::External(
            __("AD LDAP server does not support GSSAPI"));
    }

    # Finally bind to LDAP using our SASL object
    my $masterBind = $masterLdap->bind(sasl => $saslClient);
    if ($masterBind->is_error()) {
        throw EBox::Exceptions::LDAP(
            message => __('Error binding to schema master LDAP:'),
            result => $masterBind);
    }

    return $masterLdap;
}

sub _sendSchemaUpdate
{
    my ($self, $masterLdap, $ldifTemplate) = @_;

    unless (defined $masterLdap) {
        throw EBox::Exceptions::MissingArgument('masterLdap');
    }
    unless (defined $ldifTemplate) {
        throw EBox::Exceptions::MissingArgument('ldifTemplate');
    }

    # Mangle LDIF
    my $defaultNC = $self->ldap->dn();
    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $ldifFile = $fh->filename();
    my $buffer = File::Slurp::read_file($ldifTemplate);
    $buffer =~ s/DOMAIN_TOP_DN/$defaultNC/g;
    EBox::debug("Mangled LDIF:\n$buffer\n");
    File::Slurp::write_file($ldifFile, $buffer);

    # Send update
    my $ldif = new Net::LDAP::LDIF($ldifFile, 'r', onerror => 'undef');
    while (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        if ($ldif->error() or not defined $entry) {
            throw EBox::Exceptions::Internal(
                __x('Error loading LDIF. Error message: {x}, Error lines: {y}',
                    x => $ldif->error(), y => $ldif->error_lines()));
        } else {
            # Check if the entry has been already loaded into schema
            my $dn = $entry->dn();
            # Skip checking the update schema cache sent to root DSE
            if ($dn ne '') {
                my $result = $masterLdap->search(
                    base => $dn,
                    scope => 'base',
                    filter => '(objectClass=*)');
                next if ($result->count() > 0);
            }

            # Send the entry
            EBox::info("Sending schema update: $dn");
            my $msg = $entry->update($masterLdap);
            if ($msg->is_error()) {
                throw EBox::Exceptions::LDAP(
                    message => "Error sending schema update: $dn",
                    result => $msg);
            }
        }
    }
    $ldif->done();
}

# Method: _loadSchemas
#
#  Load the schema-*.ldif schemas contained in the module package
#
sub _loadSchemas
{
    my ($self) = @_;
    my $path = EBox::Config::share() . "zentyal-" . $self->name();
    my @schemas = glob ("$path/schema-*.ldif");
    $self->_loadSchemasFiles(\@schemas);
}

sub _loadSchemasFiles
{
    my ($self, $schemas_r) = @_;
    my @schemas = @{ $schemas_r };
    # Locate and connect to schema master
    my $masterLdap = $self->_connectToSchemaMaster();

    foreach my $ldif (@schemas) {
        $self->_sendSchemaUpdate($masterLdap, $ldif);
    }

    my $defaultNC = $self->ldap->dn();
    # Wait for schemas replicated if we are not the master
    foreach my $ldif (@schemas) {
        my @lines = read_file($ldif);
        foreach my $line (@lines) {
            my ($dn) = $line =~ /^dn: (.*)/;
            if ($dn) {
                $dn =~ s/DOMAIN_TOP_DN/$defaultNC/;
                $self->waitForLDAPObject($dn);
              }
        }
    }
}

# Method: waitForLDAPObject
#
# Waits 30 seconds for a LDAP entry with the given dn
# If it is not seen it raises error
#
sub waitForLDAPObject
{
    my ($self, $dn) = @_;
    my $timeout = 30;
    EBox::info("Waiting for schema object present: $dn");
    while (1) {
        my $object = new EBox::Samba::LdapObject(dn => $dn);
        if ($object->exists()) {
            last;
        } else {
            sleep (1);
            $timeout--;
            if ($timeout == 0) {
                throw EBox::Exceptions::Internal("Schema object $dn not found after 30 seconds");
            }
        }
    }
}

# Method: _regenConfig
#
#   Overrides <EBox::Module::Service::_regenConfig>
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    my $samba = $self->global()->modInstance('samba');
    if ($samba->isProvisioned() and $samba->isEnabled()) {
        $self->_performSetup();
        $self->SUPER::_regenConfig(@_);
    }
}

sub _performSetup
{
    my ($self) = @_;

    my $state = $self->get_state();
    $self->_loadSchemas();
    $state->{'_schemasAdded'} = 1;
    $self->set_state($state);

    unless ($state->{'_ldapSetup'}) {
        $self->setupLDAP();
        $state->{'_ldapSetup'} = 1;
        $self->set_state($state);
    }
}

sub setupLDAP
{
}

sub setupLDAPDone
{
    my ($self) = @_;
    my $state = $self->get_state();
    return $state->{'_schemasAdded'} && $state->{'_ldapSetup'};
}

# Method: reprovisionLDAP
#
#   Reprovision LDAP setup for the module.
#
sub reprovisionLDAP
{
}

1;
