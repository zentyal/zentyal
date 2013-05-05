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

# Class: EBox::TrafficShaping::Composite::DynamicGeneral
#
#   This class is used to manage traffic shaping rule models in a
#   single element using a dynamic view
#
use strict;
use warnings;

package EBox::TrafficShaping::Composite::Rules;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Method: precondition
#
#    Check there are enough interfaces to shape the traffic in Zentyal
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
    if (not $enough) {
        return __x('Traffic Shaping is applied when Zentyal is acting as '
                   . 'a gateway. To achieve this, you need at least an internal '
                   . 'and an external interface. Check your interface '
                   . 'configuration to match, at '
                   . '{openhref}Network->Interfaces{closehref}',
                   openhref  => '<a href="/Network/Ifaces">',
                   closehref => '</a>');
    } else {
        # The cause are the configured gateways
        return __x('Traffic Shaping is applied only if there are '
                   . 'gateways with an upload rate set associated '
                   . 'with an external interface. In order to do '
                   . 'so, create a gateway at '
                   . '{openhref}Network->Gateways{closehref} '
                   . 'setting as interface an external one.',
                   openhref => '<a href="/Network/View/GatewayTable">',
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
    my $printableName = __('Traffic Shaping');
    my $description = {
       layout          => 'top-bottom',
       name            => 'Rules',
       printableName   => $printableName,
       pageTitle       => $printableName,
       compositeDomain => 'TrafficShaping',
       help            => __('Here you can add the traffic shaping rules for your internal and external interfaces'),
    };

    return $description;
}

1;
