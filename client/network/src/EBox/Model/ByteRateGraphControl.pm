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

package EBox::Network::Model::ByteRateGraphControl;
use base 'EBox::Model::ImageControl';
#

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;


sub _imageModel
{
  my ($self) = @_;
  
  my $network = EBox::Global->modInstance('network');
  return $network->model('ByteRateGraph');
}
 
sub _tableDesc
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
					    'optional' => 0, 
					    defaultValue    => 'activeSrcsGraph',
					    editable => 1,
					    populate => $graphTypePopulateSub_r,
					   ),
		    new EBox::Types::HostIP(
					    printableName  => __('Source'),
					    'fieldName' => 'source',
					    'size' => 15,
					    'optional' => 1, 
					    editable => 1,
					   ),
		    new EBox::Types::Text(
					  printableName  => __('Service'),
					  'fieldName' => 'netService',
					  'size' => 20,
					  'optional' => 1, 
					  editable => 1,					    
					 ),
		   );

  return \@tableHead;
}


sub printableName
{
  return  __('Select traffic graphic');
}



my %paramsByGraphType = (
			 activeSrcsGraph =>  {} ,
			 activeServicesGraph  =>  {},
			 srcGraph  => { source => 1 },
			 serviceGraph => { service => 1 },
			 srcAndServiceGraph => { source => 1, service => 1 },

			);

sub validateTypedRow
{
  my ($self, $action,  $changedFields, $allFields) = @_;

  exists $allFields->{'graphType'}  or throw EBox::Exceptions::MissingArgument('graphType');
  my $graphType = $allFields->{'graphType'}->value();

  exists $paramsByGraphType{$graphType} or
    throw EBox::Exceptions::External(
            __x('Unknown graph type {t}', t => $graphType)
				    );

  my %paramsSpec =  %{ $paramsByGraphType{$graphType} };

  while (my ($name, $object) = each %{ $allFields }) {
    next if ($name eq 'graphType');

    my $empty;
    my $value =   $object->value();
    if ($value) {
      $empty = ($value =~ m/^\s*$/);
    }
    else {
      $empty = 1;
    }

    if (not exists $paramsSpec{$name}) {
      next if $empty;
      throw EBox::Exceptions::External(
	  __x('The parameter {p} is not needed for this graphic type', p => $name)
				      );
    }
    else {
      if ($empty) {
	throw EBox::Exceptions::MissingArgument($name);	
      }
    }

    delete $paramsSpec{$name};
  }

  my ($missingParameter) = keys %paramsSpec;
  if ($missingParameter) {
    throw EBox::Exceptions::MissingArgument($missingParameter);
  }

}



1;
