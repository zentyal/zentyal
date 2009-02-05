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

package EBox::Squid::Model::NoCacheDomains;


#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::DomainName;
use EBox::Validate;

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
#       <EBox::Squid::Model::DomainFilter> - the recently
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
#
sub _table
  {

      my @tableHeader =
        (
         new EBox::Types::DomainName(
                               fieldName     => 'domain',
                               printableName => __('Domain'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
         new EBox::Types::Boolean(
                               fieldName     => 'noCache',
                               printableName => __('Exempt domain from caching'),
                               defaultValue  => 1,
                              ),
        );

      my $dataTable =
      {
          tableName          => 'NoCacheDomains',
          printableTableName => __('Cache exemptions'),
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/NoCacheDomains',
          'defaultActions' =>
              [	
              'add', 'del',
              'editField',
              'changeView'
              ],
          tableDescription   => \@tableHeader,
          class              => 'dataTable',
          order              => 0,
          rowUnique          => 1,
          printableRowName   => __('internet domain'),
          help               => __('You can exempt some domains from caching'),
          messages           => {
                                  add => __('Domain added'),
                                  del => __('Domain removed'),
                                  update => __('Domain updated'),

                                },
          sortedBy           => 'domain',
      };

  }




sub notCachedDomains
{
  my ($self, $policy) = @_;

  my @domains = map {
      if ($_->valueByName('noCache')) {
          $_->valueByName('domain');
      }
      else {
          ()
      }
  } @{ $self->rows() };


  return \@domains;
}

1;

