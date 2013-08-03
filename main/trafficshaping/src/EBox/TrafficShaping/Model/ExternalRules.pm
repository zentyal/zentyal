# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::TrafficShaping::Model::RuleTableBase
#
#   This class describes a model which contains rule to do traffic
#   shaping on a given interface. It serves as a model template which
#   has as many instances as interfaces have the machine managed by
#   Zentyal. It is a quite complicated model and it is highly coupled to
#   <EBox::TrafficShaping> module itself.
#
use strict;
use warnings;

package EBox::TrafficShaping::Model::ExternalRules;

use base 'EBox::TrafficShaping::Model::RuleTableBase';

use EBox::Gettext;

# Constructor: new
#
#       Constructor for Traffic Shaping Table Model
#
# Returns :
#
#      A recently created <EBox::TrafficShaping::Model::ExternalRules> object
#
sub new
{
    my $class = shift;
    my (%params) = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    $self->{tableName} = 'ExternalRules';
    $self->{printableTableName} = __('Rules for external interfaces (upload)');

    return $self;
}

# Method: ids
#
#   This method is overriden to set up some module internal data structure which depends on the
#   external interface
#
# Overrides :
#
#   EBox::Model::DataTable::ids
#
sub ids
{
    my ($self) = @_;

    if (not $self->{stateRateSet}) {
        my $network = $self->global()->modInstance('network');
        foreach my $iface (@{ $network->ExternalIfaces }) {
            $self->_setStateRate($iface, $self->{ts}->uploadRate($iface));
        }
        $self->{stateRateSet} = 1;
    }

    return $self->SUPER::ids();
}

sub allIfacesForRuleTable
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
    my $ifaces =   $network->ExternalIfaces();
    return $ifaces;
}

# Method: notifyForeignModelAction
#
#      Called whenever an action is performed on the interface rate model
#
# Overrides:
#
#      <EBox::Model::DataTable::notifyForeignModelAction>
#
sub notifyForeignModelAction
{
    my ($self, $modelName, $action, $row) = @_;
    if ($modelName ne 'trafficshaping/InterfaceRate') {
        return;
    }

    my $iface = $row->valueByName('interface');

    my $userNotes = '';
    if ($action eq 'update') {
        my $netMod = $self->global()->modInstance('network');
            # Check new bandwidth
            my $limitRate;
            if ( $netMod->ifaceIsExternal($iface)) {
                $limitRate = $self->{ts}->uploadRate($iface);
            } else {
                # Internal interface
                $limitRate = $self->{ts}->totalDownloadRate($iface);
            }
            if ( $limitRate == 0 or (not $self->{ts}->enoughInterfaces())) {
                $userNotes = $self->_removeRules($iface);
            } else {
                $userNotes = $self->_normalize($iface, $self->_stateRate($iface), $limitRate);
            }
            $self->_setStateRate($iface, $limitRate );
    }
    return $userNotes;
}

1;
