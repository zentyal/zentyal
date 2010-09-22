# Copyright (C) 2009-2010 eBox Technologies S.L.
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

# Class: EBox::IDS::Composite::General
#
#   Class description
#

package EBox::IDS::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;

# Constants
use constant STORE_URL => 'https://store.zentyal.com/other/advanced-security.html?utm_source=zentyal&utm_medium=IDS&utm_campaign=advanced_security_updates';


# Group: Public methods

# Constructor: new
#
#         Constructor for the composite
#
# Returns:
#
#       <EBox::IDS::Model::Composite> - a
#       composite
#
sub new
{

    my ($class) = @_;

    my $self = $class->SUPER::new();

    return $self;
}

# Method: permanentMessage
#
#     Override to show a message depending on the subscription status
#
# Overrides:
#
#     <EBox::Model::Composite::permanentMessage>
#
sub permanentMessage
{
    my ($self) = @_;

    unless ( $self->{advancedSec} ) {
        my $securityUpdatesAddOn = 0;
        if ( EBox::Global->modExists('remoteservices') ) {
            my $rs = EBox::Global->modInstance('remoteservices');
            $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
        }

        unless ( $securityUpdatesAddOn ) {
            $self->{permanentMessage} = $self->_commercialMsg();
        }
        $self->{advancedSec} = 1;
    }

    return $self->{permanentMessage};

}

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{

    my $description =
    {
        components      => [
                            'ids/Interfaces',
                            'ids/Rules',
                           ],
        layout          => 'tabbed',
        name            => __PACKAGE__->nameFromClass,
        pageTitle       => __('Intrusion Detection System'),
        compositeDomain => 'IDS',
#        help            => __('help message'),
    };

    return $description;
}

# Group: Private methods

# Commercial message
sub _commercialMsg
{
    return __sx(
        'Get IDS updates to protect your system against the latest security '
        . 'threats such as hacking attempts and attacks on security '
        . 'vulnerabilities! The IDS updates are integrated in the {openhref} '
        . 'Advanced Security Updates{closehref} subscription that guarantees '
        . 'that the Antispam, Intrusion Detection System, Content filtering '
        . 'system and Antivirus installed on your Zentyal server are updated '
        . 'on daily basis based on the information provided by the most '
        . 'trusted IT experts.',
        openhref  => '<a href="' . STORE_URL . '" target="_blank">',
        closehref => '</a>');

}

1;
