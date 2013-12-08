# Copyright (C) 2009-2012 Zentyal S.L.
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
use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=IDS&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=IDS&utm_campaign=enterprise_edition';


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

sub permanentMessageType
{
    return 'ad';
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
    };

    return $description;
}

# Group: Private methods

# Commercial message
sub _commercialMsg
{
    return __sx('Want to protect your system against the latest security threats, hacking attempts and attacks on security vulnerabilities? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} that include the IDS feature in the automatic security updates.',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

1;
