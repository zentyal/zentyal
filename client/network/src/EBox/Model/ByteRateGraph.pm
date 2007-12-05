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


      my $dataTable =
        {
         tableName          => 'ByteRateGraph',
         printableTableName => __('Byte rate'),
	 modelDomain        => 'Network',
#         help               => __(''),

			'defaultActions' =>
				[	
				'changeView'
				],
				
	};


      return $dataTable;
  }


sub _generateImage
{
  my ($class, $file) = @_;

  my $startTime = -600;

      EBox::Network::Report::ByteRate::activeSrcsGraph(
						   startTime => $startTime,
						   file      => $file,
						  );
}


1;
