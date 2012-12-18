#!/usr/bin/perl

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

# Class: EBox::UsersAndGroups::Principal
#
#   Kerberos principal, stored in LDAP
#

use strict;
use warnings;

package EBox::UsersAndGroups::Principal;

use base 'EBox::UsersAndGroups::LdapObject';

use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::UsersAndGroups;

use Perl6::Junction qw(any);
use Error qw(:try);

use constant CORE_ATTRS => ('krb5Key', 'krb5KeyVersionNumber');

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    if (defined $opts{uid}) {
        $self->{uid} = $opts{uid};
    } elsif (defined $opts{krb5PrincipalName}) {
        $self->{krb5PrincipalName} = $opts{krb5PrincipalName};
    } else {
        $self = $class->SUPER::new(@_);
    }
    bless ($self, $class);
    return $self;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the principal
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        my $filter = undef;
        if (defined $self->{uid} ) {
            $filter = "(uid=$self->{uid})";
        } elsif (defined $self->{krb5PrincipalName}){
            $filter = "(krb5PrincipalName=$self->{krb5PrincipalName})";
        }
        if (defined $filter) {
            my $result = undef;
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => $filter,
                scope => 'sub',
            };
            $result = $self->_ldap->search($attrs);
            if ($result->count() > 1) {
                throw EBox::Exceptions::Internal(
                    __x('Found {count} results for, expected only one.',
                        count => $result->count()));
            }
            $self->{entry} = $result->entry(0);
        } else {
            $self->SUPER::_entry();
        }
    }
    return $self->{entry};
}

sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::set(@_);
}

sub save
{
    my ($self) = @_;

    my $changetype = $self->_entry->changetype();

    shift @_;
    $self->SUPER::save(@_);

    if ($changetype ne 'delete') {
        if ($self->{core_changed}) {
            delete $self->{core_changed};
            my $users = EBox::Global->modInstance('users');
            $users->notifyModsLdapUserBase('modifyPrincipal', [ $self ], $self->{ignoreMods}, $self->{ignoreSlaves});
        }
    }
}

# Method: kerberosKeys
#
#     Return the Kerberos key hashes for this user
#
# Returns:
#
#     Array ref - containing three hash refs with the following keys
#         type  - Int the hash type: 18 => DES-CBC-CRC,
#                                    16 => DES-CBC-MD5,
#                                    23 => arcfour-HMAC-MD5 (AKA NTLMv2)
#         value - Octects containing the hash
#         salt  - String the salt (only valid for 18 and 16 types)
#
sub kerberosKeys
{
    my ($self) = @_;

    my $keys = [];

    my $syntaxFile = EBox::Config::scripts('users') . 'krb5Key.asn';
    my $asn = Convert::ASN1->new();
    $asn->prepare_file($syntaxFile) or
        throw EBox::Exceptions::Internal($asn->error());
    my $asn_key = $asn->find('Key') or
        throw EBox::Exceptions::Internal($asn->error());

    my @aux = $self->get('krb5Key');
    foreach my $blob (@aux) {
        my $key = $asn_key->decode($blob) or
            throw EBox::Exceptions::Internal($asn_key->error());
        push @{$keys}, {
                         type  => $key->{key}->{value}->{keytype}->{value},
                         value => $key->{key}->{value}->{keyvalue}->{value},
                         salt  => $key->{salt}->{value}->{salt}->{value}
                       };
    }

    return $keys;
}

# Method: create
#
#   Adds a new principal. If no passwords or keys specified, random one will
#   be generated.
#
# Parameters:
#
#   params - Hash containing:
#       krb5PrincipalName - The principal name
#       password (optional) - The principal password
#       keys (optional) - The principal keys
#
# Returns:
#
#   Returns the new create principal object
#
sub create
{
    my ($self, $params, $extra) = @_;

    $extra = {} unless defined $extra;
    unless (defined $params->{krb5PrincipalName}) {
        throw EBox::Exceptions::MissingArgument("krb5PrincipalName");
    }

    my $users = EBox::Global->modInstance('users');
    my $princName = $params->{krb5PrincipalName};
    my ($uid, $realm) = split (/@/, $princName);
    unless (defined $uid and defined $realm) {
        throw EBox::Exceptions::InvalidData(
            data => __('Principal name'),
            value => $princName,
            advice => 'Cannot split into uid and realm');
    }

    my $dn = "krb5PrincipalName=$princName,OU=Kerberos," . $self->_ldap->dn();
    # Verify user exists
    my $p = new EBox::UsersAndGroups::Principal(dn => $dn);
    if ($p->exists()) {
        # The principal is already created.
        $users->notifyModsLdapUserBase('modifyPrincipal', [ $p ], $extra->{ignoreMods}, $extra->{ignoreSlaves});
        return;
    }

    my @attr = (
        objectclass          => [
            'top',
            'simpleSecurityObject',
            'account',
            'krb5Principal',
            'krb5KDCEntry'],
        userPassword         => '{K5KEY}',
        uid                  => $uid,
        krb5PrincipalName    => $princName,
        krb5KeyVersionNumber => 0,
        krb5MaxLife          => 86400,  # TODO
        krb5MaxRenew         => 604800, # TODO
        krb5KDCFlags         => 126,    # TODO
    );

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attr);
        $users->notifyModsPreLdapUserBase('preAddPrincipal', $entry,
                $extra->{ignoreMods}, $extra->{ignoreSlaves});
        my $result = $entry->update($self->_ldap->ldapCon());
        if ($result->is_error()) {
            unless ($result->code() == LDAP_LOCAL_ERROR and
                    $result->error() eq 'No attributes to update') {
                throw EBox::Exceptions::Internal(__('There was an error: ') . $result->error());
            }
        }

        $res = new EBox::UsersAndGroups::Principal(dn => $dn);
        # Set the principal keys
        if (defined $params->{password}) {
            $res->_ldap->changeUserPassword($res->dn(), $params->{password});
        } elsif (defined $params->{keys}) {
            $res->set('krb5Key', $params->{keys}, 1);
            $res->set('krb5KeyVersionNumber', 1, 1);
            $res->save();
        } else {
            my $pwd = EBox::Util::Random::generate(20);
            $res->_ldap->changeUserPassword($res->dn(), $pwd);
        }
        # Force reload of krb5Keys
        $res->clearCache();

        # Call modules initialization
        $users->notifyModsLdapUserBase('addPrincipal', [ $res ], $extra->{ignoreMods}, $extra->{ignoreSlaves});
    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if (defined $res and $res->exists()) {
            $users->notifyModsLdapUserBase('addPrincipalFailed', [ $res ], $extra->{ignoreMods}, $extra->{ignoreSlaves});
            $res->SUPER::deleteObject(@_);
        } else {
            $users->notifyModsPreLdapUserBase('preAddPrincipalFailed', [ $entry ], $extra->{ignoreMods}, $extra->{ignoreSlaves});
        }
        $res = undef;
        $entry = undef;
        throw $error;
    };

    # Return the new created principal
    return $res;
}

1;
