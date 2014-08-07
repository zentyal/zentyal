# Copyright (C) 2009-2013 Zentyal S.L.
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

# Class: EBox::IPS::Composite::General
#
#   Class description
#

use strict;
use warnings;

package EBox::IPS::Composite::General;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;
use EBox::Config;

# Group: Public methods

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
        layout          => 'tabbed',
        name            => __PACKAGE__->nameFromClass,
        pageTitle       => __('Intrusion Detection/Prevention System'),
        compositeDomain => 'IPS',
    };

    return $description;
}

# Group: Private methods

# Commercial message
sub _commercialMsg
{
    return __sx('Want to protect your system against the latest security threats, hacking attempts and attacks on security vulnerabilities? Get  one of the {oh}Commercial Editions{ch} that include the IPS feature in the automatic security updates.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

1;
