# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::Squid::Model::FilterGroupDomainFilterCategories;
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
      my $tableHeader = $self->_tableHeader();
      my $dataTable =
      {
          tableName          => 'FilterGroupDomainFilterCategories',
          printableTableName => __('Domains list categories'),
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/FilterGroupDomainFilterCategories',
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

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
sub viewCustomizer
{
    my ($self) = @_;

    my $manager = EBox::Model::ModelManager->instance();
    my $rowId = [split('/', $self->parentRow()->dir())]->[2];
    my $profile = $manager->model('squid/FilterGroup')
        ->row($rowId)
        ->valueByName('name');
    my $dir = "FilterGroup/keys/$rowId/filterPolicy";
    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([
            {
            title => __('Filter Profiles'),
            link  => '/ebox/Squid/View/FilterGroup',
            },
            {
            title => $profile,
            link  => "/ebox/Squid/Composite/FilterGroupSettings?directory=$dir" .
            "#FilterGroupDomains",
            },
            {
            title => $self->parentRow()->valueByName('description'),
            link => ''
            }
            ]);

    return $custom;
}

1;

