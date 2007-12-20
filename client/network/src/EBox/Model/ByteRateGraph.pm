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
package EBox::Network::Model::ByteRateGraph;
use base 'EBox::Model::Image';
#
use strict;
use warnings;

use EBox::Gettext;
use EBox::Network::Report::ByteRate;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Types::Select;

use EBox::Exceptions::DataNotFound;

use Error qw(:try);

sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless $self, $class;
      return $self;

  }

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#

#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
#
sub _table
{
  my $graphTypePopulateSub_r  = sub {
    return [
	    {
	     value => 'activeSrcsGraph',
	     printableValue => __('Active sources traffic'),
	    },
	    {
	     value => 'activeServicesGraph',
	     printableValue => __('Active services traffic'),
	    },
	    {
	     value => 'srcGraph',
	     printableValue => __('Source traffic'),
	    },
	    {
	     value => 'serviceGraph',
	       printableValue => __('Service traffic'),
	    },	
	    {
	     value => 'srcAndServiceGraph',
	     printableValue => __('Source and service traffic'),
	    },
	    
	   ];
  };

    my  @tableHead = (
		      new EBox::Types::Select(
					    printableName  => __('Graph type'),
					    'fieldName' => 'graphType',
					    'size' => '10',
					    'optional' => 0, 
					    defaultValue    => 'activeSrcsGraph',
#					    'hidden' => 1,
					    editable => 1,
					    populate => $graphTypePopulateSub_r,
					   ),
		      new EBox::Types::HostIP(
					    printableName  => __('Source'),
					    'fieldName' => 'source',
					    'size' => '40',
					    'optional' => 1, 
#					    'hidden' => 1,
					    editable => 1,
					   ),
		      new EBox::Types::Text(
					    printableName  => __('Service'),
					    'fieldName' => 'netService',
					    'size' => '40',
					    'optional' => 1, 
#					    'hidden' => 1,
					    editable => 1,					    
					   ),
		     );

  my $dataTable = {
		   'tableDescription' => \@tableHead,
		   tableName          => 'ByteRateGraph',
#		   printableTableName => __('Byte rate'),
		   modelDomain        => 'Network',
		   #         help               => __(''),

		   'defaultActions' =>
		   [
		    'editField',
		    'changeView',
		   ],
	 
		  };


  return $dataTable;
}


sub _generateImage
{
  my ($self, $file) = @_;

  my $startTime = -600;

  my @commonArguments = (
			 startTime => $startTime,
			 file      => $file,
			);

  my $sub_r         = $self->_graphSub();
  my @subArguments  = $self->_graphSubArguments();

  my $error = undef;
  try {
    $sub_r->(
	     @commonArguments,
	     @subArguments,
	    );
  }
  catch EBox::Exceptions::DataNotFound with  {
    my $ex = shift;
    $error = $ex->text;
  };

  if (defined $error) {
    return { image => 0, error => $error };
  }


  return { image => 1 };
}


sub _graphSub
{
  my ($self) = @_;

  my $graphType = $self->graphTypeValue();
  my $graphSub = EBox::Network::Report::ByteRate->can($graphType);
  EBox::debug("GRAPH SUB $graphType $graphSub");
  if (not $graphSub) {
    throw EBox::Exceptions::Internal("Unknown graph type: $graphType");
  }  

  return $graphSub;
}

sub _graphSubArguments
{
  my ($self) = @_;
  my $graphType = $self->graphTypeValue();

  if ($graphType eq 'srcGraph') {
    return (source => $self->sourceValue);
  }
  elsif ($graphType eq 'serviceGraph') {
    return (service => $self->netServiceValue);
  }
  elsif ($graphType eq 'srcAndServiceGraph') {
    return (source => $self->sourceValue , service => $self->netServiceValue);
  }
  else {
    return ()
  }

}

# XXX ugly fix
# we need to manage this in the arent class itself
sub _setTypedRow
{
  my ($self, @params) = @_;
  my $modName = 'network';
  my $global  = EBox::Global->modInstance('global');
  my $changed = $global->modIsChanged($modName);

  $self->SUPER::_setTypedRow(@params);

  if (not $changed) {

    $global->set_bool("modules/$modName/changed", undef);
  }
}
 

1;
