# Copyright (C) 2010-2013 Zentyal S.L.
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

package ZentyalDesktop::LDAP;

use strict;
use warnings;

use Net::LDAP;

sub new
{
    my ($class, $server, $user) = @_;

    my $self = {};

    $self->{ldap} = undef;
    $self->{server} = $server;
    $self->{user} = $user;
    $self->{ldapurl} = "ldap://$server";

    bless($self, $class);
    return $self;
}

sub connect
{
    my ($self) = @_;

    unless ($self->{ldap}) {
        my $ldap = new Net::LDAP($self->{ldapurl});
        $ldap->bind();
        $self->{ldap} = $ldap;
    }

    return $self->{ldap};
}


sub servicesInfo
{
    my ($self) = @_;

    my $baseDn = $self->dn();
    my $user = $self->{user};
    my $dn = "uid=$user,ou=Users,$baseDn";

    my $mailAccount = $self->getAttribute($dn, 'mail');
    my $hasZarafaAccount = $self->isObjectClass($dn, 'zarafa-user');
    my $hasSambaAccount = $self->isObjectClass($dn, 'sambaSamAccount');
    my $hasJabberAccount = $self->isObjectClass($dn, 'userJabberAccount');
    my $hasVoIPAccount = $self->isObjectClass($dn, 'AsteriskSIPUser');

    my $services = {};

    # FIXME: Unhardcode this when possible
    $services->{UserCorner} = { port => 8888 };

    if ((defined $mailAccount) and ($mailAccount ne '')) {
        $services->{Mail} = { account => $mailAccount };
    }

    if ($hasZarafaAccount) {
        $services->{Zarafa} = {};
    }

    if ($hasSambaAccount) {
        my $groupShares = {};
        foreach my $group ($self->groups()) {
            my $groupDn = "cn=$group,ou=Groups,$baseDn";
            my $share = $self->getAttribute($groupDn, 'displayResource');
            if ($share) {
                my $desc = $self->getAttribute($groupDn, 'description');
                $groupShares->{$group} = { share => $share,
                                           desc  => $desc };
            }
        }
        $services->{Samba} = { groupShares => $groupShares };
    }

    if ($hasJabberAccount) {
        my $domain = $baseDn;
        $domain =~ s/,dc=/\./g;
        $domain =~ s/dc=//g;
        $services->{Jabber} = { domain => $domain };
    }

    if ($hasVoIPAccount) {
        $services->{VoIP} = {};
    }

    return $services;
}

# Method: groups
#
#       Returns an array containing all the groups
#
# Returns:
#
#       array - holding the groups
#
sub groups
{
    my ($self) = @_;

    my $baseDn = $self->dn();

    my %args = (
                base => "ou=Groups,$baseDn",
                filter => '(objectclass=*)',
                scope => 'one',
                attrs => ['cn']
               );

    my $result = $self->{ldap}->search(%args);

    my @groups = map { $_->get_value('cn') } $result->entries();

    return @groups;
}

# Method: isObjectClass
#
#      check if a object is member of a given objectclass
#
# Parameters:
#          dn          - the object's dn
#          objectclass - the name of the objectclass
#
#  Returns:
#    boolean - wether the object is member of the objectclass or not
#
sub isObjectClass
{
    my ($self, $dn, $objectClass) = @_;

    my %attrs = (
            base   => $dn,
            filter => "(objectclass=$objectClass)",
            attrs  => [ 'objectClass'],
            scope  => 'base'
            );

    my $ldap = $self->connect();
    my $result = $ldap->search(%attrs);

    if ($result->count ==  1) {
        return 1;
    }

    return undef;
}

# Method: getAttribute
#
#       Get the value for the given attribute.
#       If there are more than one, the first is returned.
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to get its value
#
# Returns:
#       string - attribute value if present
#       undef  - if attribute not present
#
sub getAttribute # (dn, attribute);
{
    my ($self, $dn, $attribute) = @_;

    my $ldap = $self->connect();

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $ldap->search(%args);

    return undef unless ($result->count > 0);

    return $result->entry(0)->get_value($attribute);
}

# Method: dn
#
#       Returns the base DN (Distinguished Name)
#
# Returns:
#
#       string - DN
#
sub dn
{
    my ($self) = @_;

    if(!defined($self->{dn})) {
        my $ldap = $self->connect();

        my %args = (
            'base' => '',
            'scope' => 'base',
            'filter' => '(objectclass=*)',
            'attrs' => ['namingContexts']
        );
        my $result = $ldap->search(%args);
        my $entry = ($result->entries)[0];
        my $attr = ($entry->attributes)[0];
        $self->{dn} = $entry->get_value($attr);
    }

    return $self->{dn};
}

1;
