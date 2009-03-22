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

package EBox::AsteriskExtensions;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Ldap;
use EBox::Asterisk;

use constant EXTENSIONSDN        => 'ou=Extensions';


sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{asterisk} = EBox::Global->modInstance('asterisk');
    bless($self, $class);
    return $self;
}


# Method: extensionsDn
#
#       Returns the dn where the extensions are stored in the ldap directory
#
# Returns:
#
#       string - dn
#
sub extensionsDn
{
    my ($self) = @_;
    return EXTENSIONSDN . "," . $self->{ldap}->dn;
}


# Method: extensions
#
#  This method returns all defined extensions
#
# Returns:
#
#     array - with all extensions names
#
sub extensions
{
    my ($self) = @_;

    my %args = (
                base => $self->extensionsDn,
                filter => 'objectclass=AsteriskExtension',
                scope => 'sub',
               );

    my $result = $self->{ldap}->search(\%args);

    my @extns = map { $_->get_value('cn')} $result->sorted('cn');

    return @extns;
}


# Method: addUserExtension
#
sub addUserExtension
{
    my ($self, $user, $extn) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    $self->addExtension($extn, '1', 'Dial', "SIP/$user");
    $self->addExtension($extn, '2', 'Voicemail', "$extn,u"); #FIXME voicemail=extn
}


# Method: addExtension
#
sub addExtension
{
    my ($self, $extn, $prio, $app, $data) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $ldap = $self->{ldap};

    my $dn = "cn=$extn-$prio," . $self->extensionsDn;

    my %attrs = (
                 attr => [
                         objectClass => 'applicationProcess',
                         objectClass => 'AsteriskExtension',
                         AstContext => 'default',
                         AstExtension => $extn,
                         AstPriority => $prio,
                         AstApplication => $app,
                         AstApplicationData => $data,
                        ],
                 
                );

    $self->{'ldap'}->add($dn, \%attrs);
}


# Method: delExtension
#
sub delExtension
{
    my ($self, $cn) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $ldap = $self->{ldap};

    my $dn = "cn=$cn," . $self->extensionsDn;

    $ldap->delete($dn);
}


1;
