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
    my  @tableHead = (
		      new EBox::Types::Text(
					    printableName  => __('Graph type'),
					    'fieldName' => 'graphType',
					    'size' => '10',
					    'optional' => 1, 
					    defaultValue    => 'activeSrcsGraph',
#					    'hidden' => 1,
					    editable => 1,
					   ),
		      new EBox::Types::Text(
					    printableName  => __('Graph parameters'),
					    'fieldName' => 'graphArguments',
					    'size' => '40',
					    'optional' => 1, 
					    defaultValue    => '',
#					    'hidden' => 1,
					    editable => 1,
					   ),
		     );

      my $dataTable =
        {
	 'tableDescription' => \@tableHead,
         tableName          => 'ByteRateGraph',
         printableTableName => __('Byte rate'),
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

  
  $sub_r->(
	   @commonArguments,
	   @subArguments,
	  );

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
  my $graphArguments = $self->graphArgumentsValue();
  $graphArguments or
    return ();

  my @args = split '\s+', $graphArguments;
  return @args;
}


1;
