# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::LdapModule;

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Ldap;

use Error qw(:try);

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: _ldapModImplementation
#
#      	All modules using any of the functions in LdapUserBase.pm
#   	should override this method to return the implementation
#	of that interface.
#
# Returns:
#
#	An object implementing EBox::LdapUserBase 
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

    my $users = EBox::Global->modInstance('users');

    unless(defined($self->{ldap})) {
        $self->{ldap} = EBox::Ldap->instance();
    }
    return $self->{ldap};
}

sub masterLdap
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $ldap;
    if ($users->isMaster()) {
        $self->ldap->ldapCon();
        $ldap = $self->ldap->{ldap};
    } else {
        my $remote = $users->remoteLdap();
        my $password = $users->remotePassword();
        $ldap = Net::LDAP->new("ldap://$remote");
        $ldap->bind($self->ldap->rootDn(), password => $password);
    }
    return $ldap;
}

#   Method: loadSchema
#
#      loads an LDAP schema from an LDIF file
#
# Parameters:
#          file - LDIF file
#
sub loadSchema
{
    my ($self, $ldiffile) = @_;

    my $users = EBox::Global->modInstance('users');

    if ($users->isMaster()) {
        $self->ldap->ldapCon();
        my $ldap = $self->ldap->{ldap};
        $self->_loadSchema($ldap, $ldiffile);
    } else {
        my $password = $self->ldap->getPassword();
        my $ldap;
        my @ports = (389, 1389, 1390);
        for my $port (@ports) {
            for (0..4) {
                $ldap = Net::LDAP->new("127.0.0.1:$port");
                last if defined($ldap);
                sleep(1);
            }
            defined($ldap) or throw EBox::Exceptions::Internal("Can't connect to LDAP on port $port");
            $ldap->bind('cn=admin,cn=config', 'password' => $password);
            $self->_loadSchema($ldap, $ldiffile);
        }
    }
}

sub _loadSchema
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
        if ($result->entries eq 0) {
            $result = $ldap->add($entry);
            if ($result->is_error()) {
                EBox::debug($result->error());
            }
        }
    }
    $ldif->done();
}

#   Method: loadACL
#
#      loads an ACL
#
# Parameters:
#          acl - string with the ACL (it has to start with 'to')
#
sub loadACL
{
    my ($self, $acl) = @_;

    my $users = EBox::Global->modInstance('users');

    if ($users->isMaster()) {
        $self->ldap->ldapCon();
        my $ldap = $self->ldap->{ldap};
        $self->_loadACL($ldap, $acl);
    } else {
        my $password = $self->ldap->getPassword();
        my $ldap;
        my @ports = (389, 1389, 1390);
        for my $port (@ports) {
            for (0..4) {
                $ldap = Net::LDAP->new("127.0.0.1:$port");
                last if defined($ldap);
                sleep(1);
            }
            defined($ldap) or throw EBox::Exceptions::Internal("Can't connect to LDAP on port $port");
            $ldap->bind('cn=admin,cn=config', 'password' => $password);
            $self->_loadACL($ldap, $acl);
        }
    }
}

sub _loadACL
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
    my $attr = ($entry->attributes)[0];
    my $found = undef;
    my @rules = $entry->get_value($attr);
    for my $access (@rules) {
        if($access =~ m/^{\d+}\Q$acl\E$/) {
            $found = 1;
            last;
        }
    }
    if(not $found) {
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
        } otherwise {
            throw EBox::Exceptions::Internal("Invalid ACL: $acl");
        };
    }
}
#   Method: addTranslucentLocalAttribute
#
#      adds an attribute as local in the translucent LDAP
#
# Parameters:
#          attribute - string with the attribute name
#
sub addTranslucentLocalAttribute
{
    my ($self, $attribute) = @_;

    my $users = EBox::Global->modInstance('users');

    $users->stopIfRequired();
    EBox::Sudo::root("sed -i -e 's/^olcTranslucentLocal: \\(.*\\)/olcTranslucentLocal: \\1,$attribute/' /etc/ldap/slapd-translucent.d/cn=config/olcDatabase={1}hdb/olcOverlay={0}translucent.ldif");
    $users->restoreState();
}

1;
