# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::LdapModule;

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;

use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: _ldapModImplementation
#
#   All modules using any of the functions in LdapUserBase.pm
#   should override this method to return the implementation
#   of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
sub _ldapModImplementation
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: ldap
#
#   Provides an EBox::Ldap object with the proper configuration for the
#   LDAP setup of this ebox
sub ldap
{
    my ($self) = @_;

    unless(defined($self->{ldap})) {
        $self->{ldap} = EBox::Global->modInstance('users')->newLDAP();
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

# Method: _loadSchema
#
#      loads an LDAP schema from an LDIF file
#
# Parameters:
#          file - LDIF file
#
sub _loadSchema
{
    my ($self, $ldiffile) = @_;

    $self->ldap->connection();
    my $ldap = $self->ldap->{ldap};
    $self->_loadSchemaDirectory($ldap, $ldiffile);
}

sub _loadSchemaDirectory
{
    my ($self, $ldap, $ldiffile) = @_;
    my $ldif = Net::LDAP::LDIF->new($ldiffile, "r", onerror => 'undef' );
    defined($ldif) or throw EBox::Exceptions::Internal(
            "Can't load LDIF file: " . $ldiffile);

    while(not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        if ($ldif->error()) {
            throw EBox::Exceptions::Internal(
                "Can't load LDIF file: " . $ldiffile);
        }
        my $dn = $entry->dn();
        $dn =~ m/^cn=(.*?),cn=schema,cn=config$/;
        my $schemaname = $1;
        my %args = (
            'base' => 'cn=schema,cn=config',
            'scope' => 'subtree',
            'filter' => "(cn={*}$schemaname)",
            'attrs' => ['objectClass']
        );
        my $result = $ldap->search(%args);
        if ($result->entries() == 0) {
            $result = $ldap->add($entry);
            if ($result->is_error()) {
                EBox::error($result->error());
            }
        }
    }
    $ldif->done();
}

#   Method: _loadACL
#
#      loads an ACL
#
# Parameters:
#          acl - string with the ACL (it has to start with 'to')
#
sub _loadACL
{
    my ($self, $acl) = @_;

    $self->ldap->connection();
    my $ldap = $self->ldap->{ldap};
    $self->_loadACLDirectory($ldap, $acl);
}

sub _loadACLDirectory
{
    my ($self, $ldap, $acl) = @_;

    my $dn = 'olcDatabase={1}hdb,cn=config';
    my %args = (
            'base' => $dn,
            'scope' => 'base',
            'filter' => "(objectClass=*)",
            'attrs' => ['olcAccess']
    );
    my $result = $ldap->search(%args);
    my $entry = ($result->entries)[0];
    if ($result->count() == 0) {
        throw EBox::Exceptions::Internal("LDAP object not found: $dn")
    }

    my $attr = ($entry->attributes)[0];
    my $found = undef;
    my @rules = $entry->get_value($attr);
    for my $access (@rules) {
        if($access =~ m/^{\d+}\Q$acl\E$/) {
            $found = 1;
            last;
        }
    }
    if (not $found) {
        # place the new rule *before* the last 'catch-all' one
        my $last = pop(@rules);
        $last =~ s/^{\d+}//;
        push(@rules, $acl);
        push(@rules, $last);
        my %args = (
            'replace' => [ 'olcAccess' => \@rules ]
        );
        try {
            $ldap->modify($dn, %args);
        } catch {
            throw EBox::Exceptions::Internal("Invalid ACL: $acl");
        }
    }
}

#   Method: _addIndex
#
#       Create indexes in LDAP for an attribute
#
# Parameters:
#          attribute - string with the attribute to be indexed in LDAP
#
sub _addIndex
{
    my ($self, $attribute) = @_;

    $self->ldap->connection();
    my $ldap = $self->ldap->{ldap};
    $self->_addIndexDirectory($ldap, $attribute);
}

sub _addIndexDirectory
{
    my ($self, $ldap, $attribute) = @_;

    my $index = "$attribute eq";

    my $dn = 'olcDatabase={1}hdb,cn=config';
    my %args = (
            'base' => $dn,
            'scope' => 'base',
            'filter' => "(objectClass=*)",
            'attrs' => ['olcDbIndex']
    );
    my $result = $ldap->search(%args);
    my $entry = ($result->entries)[0];
    my $attr = ($entry->attributes)[0];
    my $found = undef;
    my @indexes = $entry->get_value($attr);
    for my $dbindex (@indexes) {
        if($dbindex eq $index) {
            $found = 1;
            last;
        }
    }
    if(not $found) {
        push(@indexes, $index);
        my %args = (
            'replace' => [ 'olcDbIndex' => \@indexes ]
        );
        try {
            $ldap->modify($dn, %args);
        } catch {
            throw EBox::Exceptions::Internal("Invalid index: $index");
        }
    }
}

# Method: performLDAPActions
#
#  adds the schemas, acls and local attributes specified in the
#  LdapUserImplementation
#
# Parameters:
#          attribute - string with the attribute name
#
sub performLDAPActions
{
    my ($self) = @_;

    my $ldapuser = $self->_ldapModImplementation();
    my @schemas = @{ $ldapuser->schemas() };
    for my $schema (@schemas) {
        $self->_loadSchema($schema);
    }
    my @acls = @{ $ldapuser->acls() };
    for my $acl (@acls) {
        $self->_loadACL($acl);
    }
    my @indexes = @{ $ldapuser->indexes() };
    for my $index (@indexes) {
        $self->_addIndex($index);
    }
}

# Method: reprovisionLDAP
#
#   reprovision LDAP setup for the module. This should install schemas, create
#   initial tree, etc
#
#   It default implementation just calls performLDAPActions
sub reprovisionLDAP
{
    my ($self) = @_;
    $self->performLDAPActions();
}

# Method: slaveSetup
#
#  this is called when the slave setup. The slave setup is done when saving
#  changes so this is normally used to modify LDAP or other tasks which don't
#  change configuration.
#
#  The default implementation just calls reprovisionLDAP
#
# For changing configuration before the save changes we will use the
# preSlaveSetup methos which currently is only called for module mail
sub slaveSetup
{
    my ($self) = @_;
    $self->reprovisionLDAP();
}

# Method: preSlaveSetup
#
#  This is called to made change in the module when the server
#  is configured to enter in slave mode. Configuration changes
#  should be done there and will be committed in the next saving of changes.
#
# Parameters:
#  master - master type
#
sub preSlaveSetup
{
    my ($self, $master) = @_;
}

# Method: preSlaveSetup
#
# This method can be used to put a warning to be seen by the administrator
# before setting slave mode. The module should warn of nay destructive action
# entailed by the change of mode.
#
# Parameters:
#  master -master type
#
sub slaveSetupWarning
{
    my ($self, $master) = @_;
    return undef;
}


sub usersModesAllowed
{
    my ($self) = @_;
    my $users = $self->global()->modInstance('users');
    return [$users->STANDALONE_MODE()];
}

sub checkUsersMode
{
    my ($self) = @_;
    my $users = $self->global()->modInstance('users');
    my $mode = $users->mode();
    my $allowedMode = grep {
        $mode eq $_
    } @{ $self->usersModesAllowed() };
    if (not $allowedMode) {
        throw EBox::Exceptions::External(__x(
            'Module {mod} is uncompatible with the current users operation mode ({mode})',
            mod => $self->printableName(),
            mode => $users->model('Mode')->modePrintableName,
        ));
    }
}

1;
