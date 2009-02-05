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

package EBox::Squid::Model::MIMEFilter;
use base 'EBox::Squid::Model::MIMEFilterBase';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;




sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless  $self, $class;
      return $self;

  }


sub _table
{
    my ($self) = @_;

  my $dataTable =
    {
     tableName          => 'MIMEFilter',
     modelDomain        => 'Squid',
     printableTableName => __('Configure allowed MIME types'),
     'defaultController' => '/ebox/Squid/Controller/MIMEFilter',
     'defaultActions' =>
     [	
      'add', 'del',
      'editField',
      'changeView'
     ],
     tableDescription   => $self->_tableHeader(),
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __('MIME type'),
     help               => __("Allow/Deny the HTTP traffic of the files which the given MIME types.MIME types not listed here are allowed.\nThe  filter needs a 'filter' policy to be in effect"),

     messages           => {
         add => __('MIME type added'),
         del =>  __('MIME type removed'),
         update => __('MIME type updated'),
     },
     sortedBy           => 'MIMEType',
    };

}




1;

