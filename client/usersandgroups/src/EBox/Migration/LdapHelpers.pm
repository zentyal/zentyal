# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Migration::LdapHelpers;

use EBox;
use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Sudo;
use Net::LDAP;
use Net::LDAP::LDIF;

EBox::init();

sub _deleteAcls
{
    my ($ldap, $attrs) = @_;
    my $dn = 'olcDatabase={1}hdb,cn=config';
    my %args = (
        'base' => $dn,
        'scope' => 'base',
        'filter' => "(objectClass=*)",
        'attrs' => ['olcAccess']
    );
    my $result = $ldap->search(%args);
    for my $entry ($result->entries()) {
        my @rules = $entry->get_value('olcAccess');
        for my $attr (@{$attrs}) {
            @rules = grep { !m/$attr/ } @rules;
        }
        my %args = ( 'replace' => [ 'olcAccess' => \@rules ]);
        $ldap->modify($dn, %args);
    }
}

# Procedure: updateSchema
#
#     Update the LDAP schema for a given module
#
# Parameters:
#
#     module      - String the module name
#     schemaname  - String the schema name to update
#
#     oldACLAttrs - Array ref containing the ACL attributes from the
#                   previous schema to delete
#
#     map - Hash ref containing the modifications to be performed. The
#           key is the object class to update and the value are hash
#           refs that may contain the following key and values:
#
#             'add' - new attributes for that object class. The value
#                     is a hash ref containing as key the new
#                     attribute name and the value the attribute type
#
#             'mod' - attributes to modify its name. The value is a
#                     hash ref containing as key the old attribute name and
#                     as value the new attribute name
#
# Example:
#
# EBox::Migration::LdapHelpers::updateSchema('asterisk', 'asterisk',
#        ['AstAccountVMPassword'],
#        {
#            'AsteriskVoicemail' => {
#                'add' => {
#                    'AstContext' => 'users',
#                },
#                'mod' => {
#                    'AstAccountMailbox' => 'AstVoicemailMailbox',
#                    'AstAccountVMPassword' => 'AstVoicemailPassword',
#                    'AstAccountVMMail' => 'AstVoicemailEmail',
#                    'AstAccountVMAttach' => 'AstVoicemailAttach',
#                    'AstAccountVMDelete' => 'AstVoicemailDelete',
#                }
#            },
#            'AsteriskSIPUser' => {
#                'add' => {
#                    'AstAccountDTMFMode' => 'rfc2833',
#                    'AstAccountInsecure' => 'port',
#                },
#                'mod' => {
#                    'AstAccountLastms' => 'AstAccountLastQualifyMilliseconds'
#                }
#            }
#        }
#    );
#
sub updateSchema
{
    my ($module, $schemaname, $oldaclattrs, $map) = @_;

    my $users = EBox::Global->modInstance('users');
    my $ldap = Net::LDAP->new("ldap://127.0.0.1");
    my $dn = EBox::UsersAndGroups::baseDn($ldap);
    my $rootdn = $users->ldap->rootDn($dn);
    my $password = $users->ldap->getPassword();
    $ldap->bind($rootdn, password => $password);

    #1: get schema number
    my $schemas = $users->listSchemas($ldap);
    my $schema = (grep { /^{\d+}$schemaname$/} @{$schemas})[0];

    unless ( defined($schema) ) {
        # The module has never been configured
        EBox::info("$module has never been configured because $schemaname schema does not exist");
        return;
    }

    #2: delete ACLs that use attributes that are going to be removed
    #   this can be done either automatically or manually
    _deleteAcls($ldap, $oldaclattrs);

    my $filters = join('', map { "(objectClass=$_)" } keys(%{$map}));
    my %args = (
        'base' => $dn,
        'scope' => 'sub',
        'filter' => "(|$filters)",
        'attrs' => ['*']
    );

    my $result = $ldap->search(%args);
    my $adds = {};
#    my $deletes = {};
    for my $entry ($result->entries()) {
        my $dn = $entry->dn();
        my @objectClasses = $entry->get_value('objectClass');
        $adds->{$dn} = {};
#        $deletes->{$dn} = [];
        for my $o (@objectClasses) {
            if(defined($map->{$o})) {
                if (defined($map->{$o}->{'mod'})) {
                    for my $m (keys(%{$map->{$o}->{'mod'}})) {
    #                    push(@{$deletes->{$dn}}, $m);
                        my @mvalues = $entry->get_value($m);
                        if(@mvalues) {
                            $adds->{$dn}->{$map->{$o}->{'mod'}->{$m}} = \@mvalues;
                        }
                    }
                }
                if (defined($map->{$o}->{'add'})) {
                    for my $m (keys(%{$map->{$o}->{'add'}})) {
                        $adds->{$dn}->{$m} = $map->{$o}->{'add'}->{$m};
                    }
                }
            }
        }
    }

    #3: stop slapd
    EBox::Sudo::root('/etc/init.d/slapd stop');

    #4: replace schema with new schema
    EBox::Sudo::root("rm -f /etc/ldap/slapd.d/cn=config/cn=schema/cn=$schema.ldif");
    EBox::Sudo::root("cp /usr/share/ebox-$module/$schemaname.ldif /etc/ldap/slapd.d/cn=config/cn=schema/cn=$schema.ldif");
    EBox::Sudo::root("sed -i -e 's/,cn=schema,cn=config//' /etc/ldap/slapd.d/cn=config/cn=schema/cn=$schema.ldif");
    # Set proper permissions and owner
    EBox::Sudo::root("chown openldap:openldap /etc/ldap/slapd.d/cn=config/cn=schema/cn=$schema.ldif");
    EBox::Sudo::root("chmod go-r /etc/ldap/slapd.d/cn=config/cn=schema/cn=$schema.ldif");

    #5: start slapd
    EBox::Sudo::root('/etc/init.d/slapd start');

    sleep(1);

    $ldap = Net::LDAP->new("ldap://127.0.0.1");
    $ldap->bind($rootdn, password => $password);

    #6: go through all the objects that have the given objectclass
    #   and update their attributes
    $result = $ldap->search(%args);
    for my $entry ($result->entries()) {
        my $dn = $entry->dn();
#        my %args = ( 'add' => $adds->{$dn}, 'delete' => $deletes->{$dn});
        my %args = ('add' => $adds->{$dn});
        $ldap->modify($dn, %args);
    }

    #7: pray
    #8: introduce the new ACLs
    my $mod = EBox::Global->modInstance($module);
    my $ldapuser = $mod->_ldapModImplementation();
    my @acls = @{ $ldapuser->acls() };
    for my $acl (@acls) {
        $mod->_loadACLDirectory($ldap, $acl);
    }
}

1;
