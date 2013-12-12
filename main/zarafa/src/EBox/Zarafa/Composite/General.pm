# Copyright (C) 2010-2012 Zentyal S.L.
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

package EBox::Zarafa::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=zarafa&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=zarafa&utm_campaign=enterprise_edition';

# Group: Public methods

# Constructor: new
#
#         Constructor for the general Zarafa server composite.
#
# Returns:
#
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new();

    return $self;
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

    my $wsMod = EBox::Global->modInstance('zarafa');

    my $description =
      {
       components      => [
                           '/' . $wsMod->name() . '/VMailDomain',
                           '/' . $wsMod->name() . '/GeneralSettings',
                           '/' . $wsMod->name() . '/Gateways',
                           '/' . $wsMod->name() . '/Quota',
                          ],
       layout          => 'top-bottom',
       name            => 'General',
       printableName   => __('Configuration'),
       pageTitle       => __('Groupware (Zarafa)'),
       compositeDomain => 'Zarafa',
       help            => __('You can access the Zarafa web interface at http://zentyal_ip/webaccess and the mobile version at http://zentyal_ip/webaccess-mobile.'),
      };

    return $description;
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

    my $edition = EBox::Global->edition();
    if (($edition eq 'community') or ($edition eq 'basic')) {
        $self->{permanentMessage} = $self->_commercialMsg();
    }

    return $self->{permanentMessage};
}

sub permanentMessageType
{
    return 'ad';
}

sub _commercialMsg
{
    return __sx('Get all the advantages of Microsoft Exchange and only 50% of the costs! Zentyal fully integrates Zarafa groupware solution, an alternative to MS Exchange Server and Outlook. Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} and purchase the Zarafa Small Business add-on!',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

1;
