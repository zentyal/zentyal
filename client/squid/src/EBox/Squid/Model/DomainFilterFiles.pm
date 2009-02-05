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

package EBox::Squid::Model::DomainFilterFiles;

# Class:
#
#    EBox::Squid::Model::DomainFilterFiles
#
#
#   It subclasses <EBox::Model::DataTable>
#
use base 'EBox::Squid::Model::DomainFilterFilesBase';


use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;

use EBox::Validate;

use EBox::Sudo;

use Error qw(:try);

use constant LIST_FILE_DIR => '/etc/dansguardian/extralists';

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
          tableName          => 'DomainFilterFiles',
          printableTableName => __('Domains lists files'),
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/DomainFilterFiles',
          'defaultActions' =>
              [	
              'add', 'del',
              'editField',
              'changeView'
              ],
          tableDescription   => $tableHeader,
          class              => 'dataTable',
          order              => 0,
          rowUnique          => 1,
          printableRowName   => __('internet domain list'),
          help               => __('You can uplaod fiels whith list of domains'),
          messages           => {
                                  add => __('Domain list added'),
                                  del => __('Domain list removed'),
                                  update => __('Domain list updated'),

                                },
          sortedBy           => 'description',
      };

  }




sub listFileDir
{
    my ($self) = @_;
    return LIST_FILE_DIR;
}


sub categoryForeignModel
{
    return 'DomainFilterCategories';
}

sub categoryForeignModelView
{
    return '/ebox/Squid/View/DomainFilterCategories';
}


sub categoryBackView
{
    return '/ebox/Squid/Composite/FilterSettings';
}


# XXX fudge until #1280 is fixed
use EBox::Global;
sub parentComposite
{
    my ($self) = @_;
    my $squid = EBox::Global->modInstance('squid');
    return $squid->composite('FilterSettings');
}


1;

