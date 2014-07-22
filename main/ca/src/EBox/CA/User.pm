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

package EBox::CA::User;
use base qw(EBox::LdapUserBase);

use EBox::Gettext;

sub new
{
    my ($class, $caMod) = @_;
    my $self = {};
    $self->{caMod} = $caMod;

    bless ($self, $class);
    return $self;
}

# Method: _delUser
#
#    When a user is deleted this method is called
#
# Parameters:
#
#   user - deleted user
sub _delUser
{
}

# Method: _userAddOns
#
#    When a user is to be edited, this method is called to get customized
#    mason components from modules depending on users stored in LDAP.
#    Thus, these components will be showed below the basic user data
#    The method has to return a hash ref containing:
#    'path'   => MASON_COMPONENT_PATH_TO_BE_ADDED
#    'params' => PARAMETERS_FOR_MASON_COMPONENT
#
#    The method can also return undef to sigmnal there is not add on for the
#    module
#
# Parameters:
#
#   user - user
#
# Returns:
#
#   A hash ref containing:
#
#   path - mason component which is going to be added
#   params - parameters for the mason component
#
#   - or -
#
#   undef if there is not component to add
sub _userAddOns
{
    my ($self, $user) = @_;
    my $title = __('User certificate');

    if (not $self->{caMod}->isCreated()) {
        my $msg =  __x('{openpar}You need a valid CA certificate to create a '
            . 'user certificate. {closepar}{openpar}Please, go to the {openhref} '
            . 'certification authority module{closehref} and renew it.'
            . '{closepar}',
            openhref => qq{<a href='/CA/Index'>}, closehref => qq{</a>},
            openpar => '<p>', closepar => '</p>');
        return {
            title  => $title,
            path   => '/msg.mas',
            params => { msg => $msg }
           };
    } elsif (not $self->{caMod}->isAvailable()) {
        my $msg = __x('{openpar}You need to create a CA certificate to create a '
            .'user certificate. {closepar}{openpar}Please, go to the {openhref}'
            .'certification authority module{closehref} and create it.'
            .'{closepar}',
            openhref => qq{<a href='/CA/Index'>}, closehref => qq{</a>},
            openpar => '<p>', closepar => '</p>');
        return {
            title  => $title,
            path   => '/msg.mas',
            params => { msg => $msg }
           };
    }

    my $samAccountName = $user->get('samAccountName');
    my $cert =  $self->{caMod}->getCertificateMetadata(cn => $samAccountName);

    return {
        title  => $title,
        path   => '/ca/userCertificate.mas',
        params => {
            user => $user,
            certificate => $cert,
            caExpirationDays => $self->{caMod}->caExpirationDays()
           }
       };
}

1;
