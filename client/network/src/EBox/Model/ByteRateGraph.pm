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

  my $dataTable = {
		   'tableDescription' => [],
		   tableName          => 'ByteRateGraph',
#		   printableTableName => __('Byte rate'),
		   modelDomain        => 'Network',
		   #         help               => __(''),

		   'defaultActions' =>
		   [
		    'editField',
		    'changeView',
		   ],
		   
		   messages => {
				'add'       => undef,
				'del'       => undef,
				'update'    => undef,
				'moveUp'    => undef,
				'moveDown'  => undef,
			       }
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
  }
  catch EBox::Exceptions::MissingArgument with  {
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

  my $graphType = $self->_controlModelField('graphType');
  my $graphSub = EBox::Network::Report::ByteRate->can($graphType);

  if (not $graphSub) {
    throw EBox::Exceptions::Internal("Unknown graph type: $graphType");
  }  

  return $graphSub;
}

sub _graphSubArguments
{
  my ($self) = @_;
  my $graphType = $self->_controlModelField('graphType');

  if ($graphType eq 'srcGraph') {
    return (src  => $self->_source);
  }
  elsif ($graphType eq 'serviceGraph') {
    return (service => $self->_controlModelField('netService'));
  }
  elsif ($graphType eq 'srcAndServiceGraph') {
    return (
	    src     => $self->_source , 
	    service => $self->_controlModelField('netService')
	   );
  }
  else {
    return ()
  }

}


sub _source
{
  my ($self) = @_;

  my $unescapedSrc =  $self->_controlModelField('source');
  return EBox::Network::Report::ByteRate::escapeAddress($unescapedSrc);
}

sub _controlModel
{
  my ($self) = @_;
  
  my $network = EBox::Global->modInstance('network');
  return $network->model('ByteRateGraphControl');
}

1;
