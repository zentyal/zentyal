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

package EBox::TrafficShaping::Model::InternalRules;

use base 'EBox::TrafficShaping::Model::RuleTableBase';

use EBox::Gettext;

# Constructor: new
#
#       Constructor for Traffic Shaping Table Model
#
# Returns :
#
#      A recently created <EBox::TrafficShaping::Model::InternalRules> object
#
sub new
{
    my $class = shift;
    my (%params) = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    $self->{tableName} = 'InternalRules';
    $self->{printableTableName} = __('Rules for internal interfaces (download)');

    my $network = $self->global()->modInstance('network');
    foreach my $iface (@{ $network->InternalIfaces }) {
        $self->_setStateRate($iface, $self->{ts}->totalDownloadRate());
    }

    return $self;
}

sub allIfacesForRuleTable
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
    my $ifaces =   $network->InternalIfaces();
    return $ifaces;
}

1;
