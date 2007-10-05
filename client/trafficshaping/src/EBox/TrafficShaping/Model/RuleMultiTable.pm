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

package EBox::TrafficShaping::Model::RuleMultiTable;

use strict;
use warnings;

use EBox::Gettext;

use base 'EBox::Model::DataMultiTable';

# Constructor: new
#
#       Constructor for Traffic Shaping Multi Table Model
#
# Parameters:
#
#
# Returns :
#
#      A recently created <EBox::TrafficShaping::Model::RuleMultiTable> object
#
sub new
  {

    my $class = shift;
    my (%params) = @_;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;

  }

# Method: _multiTable
#
#       Describe the traffic shaping multitable
#
# Returns:
#
#       hash ref - multitable's description
#
sub _multiTable
  {

    my $multiTable_ref = {
			  'name'             => 'ruleMultiTable',
			  'printableName'    => __('Rules lists per interface'),
			  'actions'          => {
						 'select' => '/ebox/TrafficShaping/Controller/RuleMultiTable',
						},
			  'help'             => __('Select an interface to add traffic shaping rules. Keep in mind that if you are ' .
						   'shaping an internal interface, you are doing ingress shaping.'),
			  'optionMessage'    => __('Choose an interface to shape'),
			 };

    return $multiTable_ref;

  }

# Method: tableModel
#
#      Overrides <EBox::Model::DataMultiTable::tableModel>
#
sub tableModel # (id)
  {

    my ($self, $id) = @_;

    my $global = EBox::Global->getInstance();
    my $ts = $global->modInstance('trafficshaping');

    return $ts->ruleModel($id);

  }

# Method: selectOptions
#
#      Overrides <EBox::Model::DataMultiTable::selectOptions>
#
sub selectOptions
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $net = $global->modInstance('network');
    my $ts = $global->modInstance('trafficshaping');

    my @extIfaces = @{$net->ExternalIfaces()};
    my @intIfaces = @{$net->InternalIfaces()};

    my @options;
    foreach my $iface (@extIfaces) {
      # FIXME -> This should done by network -> Workaround to fix #373
      if ( $ts->uploadRate($iface) > 0 ) {
	my $option = {
		      id => $iface,
		      printableId => $iface,
		     };
	push (@options, $option);
      }

    }
    # Add every internal interface
    foreach my $iface (@intIfaces) {
      my $option = {
		    id => $iface,
		    printableId => $iface,
		   };
      push (@options, $option);
    }

    @options = sort { $a->{id} cmp $b->{id} } @options;

    return \@options;

  }

1;
