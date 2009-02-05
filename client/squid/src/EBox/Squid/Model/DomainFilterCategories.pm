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

package EBox::Squid::Model::DomainFilterCategories;
use base 'EBox::Squid::Model::DomainFilterCategoriesBase';

use strict;
use warnings;

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::DomainFilterFiles> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}



# Method: _table
#

sub _table
  {
      my ($self) = @_;
      my $tableHeader =  $self->_tableHeader();

      my $dataTable =
      {
          tableName          => 'DomainFilterCategories',
          printableTableName => __('Domains list categories'),
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/DomainFilterCategories',
          'defaultActions' =>
              [	
              'editField',
              'changeView'
              ],
          tableDescription   => $tableHeader,
          class              => 'dataTable',
          order              => 0,
          rowUnique          => 1,
          printableRowName   => __('category'),

          sortedBy           => 'category',
      };

  }


# # # XXX ad-hack reimplementation until the bug in coposite's parent would be
# # # solved 
# # use EBox::Global;
# sub parent
# {
#     my ($self) = @_;

#     my $squid     = EBox::Global->modInstance('squid');


#     my $defaultFilterGroup = $squid->composite('FilterSettings');
    
#     my $parent =  $defaultFilterGroup->componentByName('DomainFilterFiles', 1);

#     EBox::debug("PPARENT $parent");

#     return $parent;
# }

1;

