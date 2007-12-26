# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::TrafficShaping::Composite::DynamicGeneral
#
#   This class is used to manage traffic shaping rule models in a
#   single element using a dynamic view
#
package EBox::TrafficShaping::Composite::DynamicGeneral;

use base 'EBox::Model::Composite';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general traffic shaping composite
#
# Returns:
#
#       <EBox::TrafficShaping::Model::DynamicGeneral> - a
#       general traffic shaping composite
#
sub new
{

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

}

# Method: precondition
#
#    Check there are enough interfaces to shape the traffic in eBox
#
# Overrides:
#
#        <EBox::Model::Composite::precondition>
#
sub precondition
{
    my $tsMod = EBox::Global->modInstance('trafficshaping');
    my $enough = $tsMod->enoughInterfaces();
    unless ( $enough ) {
        return 0;
    }
    my $totalDownRate = $tsMod->totalDownloadRate();
    return ($totalDownRate > 0);
}

# Method: preconditionFailMsg
#
# Overrides:
#
#        <EBox::Model::Composite::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my $tsMod = EBox::Global->modInstance('trafficshaping');
    my $enough = $tsMod->enoughInterfaces();
    if ( not $enough ) {
        return __x('Traffic Shaping is applied when eBox is acting as '
                   . 'a gateway. To achieve this, you need at least an internal '
                   . 'and an external interface. Check your interface '
                   . 'configuration to match, at '
                   . '{openhref}Network->Interfaces{closehref}',
                   openhref  => '<a href="/ebox/Network/Ifaces">',
                   closehref => '</a>');
    } else {
        # The cause are the configured gateways
        return __x('Traffic Shaping is applied only if there are '
                   . 'gateways with an upload rate set associated '
                   . 'with an external interface. In order to do '
                   . 'so, create a gateway at '
                   . '{openhref}Network->Gateways{closehref} '
                   . 'setting as interface an external one.',
                   openhref => '<a href="/ebox/Network/View/GatewayTable">',
                   closehref => '</a>')
    }

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
                           '/trafficshaping/tsTable/*',
                          ],
       layout          => 'select',
       name            => 'DynamicGeneral',
       printableName   => __('Rules list per interface'),
       compositeDomain => 'TrafficShaping',
       help            => __('Select an interface to add traffic shaping rules. Keep in mind that if you are ' .
                             'shaping an internal interface, you are doing ingress shaping.'),
       selectMessage   => __('Choose an interface to shape'),
      };

    return $description;

}

1;

