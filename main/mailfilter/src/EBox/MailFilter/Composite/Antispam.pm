# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::MailFilter::Composite::Antispam;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;

# Constants
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=mailfilter&utm_campaign=enterprise_edition';


# Group: Public methods

# Constructor: new
#
#
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

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
                             'AntispamConfiguration',
                             'AntispamACL',
                             'AntispamTraining',
                            ],
         layout          => 'top-bottom',
         name            =>  __PACKAGE__->nameFromClass,
         printableName   => __('Antispam'),
         pageTitle	 => __('Antispam'),
         compositeDomain => 'MailFilter',
#         help            => __(''),
        };

      return $description;
}

# Group: Private methods

# Commercial message
sub _commercialMsg
{
    return __sx('Want to keep spam out of your mail servers? Get the {openhref}Enterprise Edition{closehref} that includes the Antispam feature in the automatic security updates.',
                openhref  => '<a href="' . ENT_URL . '" target="_blank">', closehref => '</a>');
}

1;
