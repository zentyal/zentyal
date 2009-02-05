# Copyright (C) 2009 Warp Networks S.L.
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

package EBox::Squid::Model::FilterGroupDomainFilterFiles;
use base 'EBox::Squid::Model::DomainFilterFilesBase';


use strict;
use warnings;

# eBox uses
use EBox;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Validate;
use EBox::Sudo;
use EBox::Global; # XXX remove when parentRow issue is fixed
use File::Basename;

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
          tableName          => 'FilterGroupDomainFilterFiles',
          printableTableName => __('Domains lists files for filter group'),
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/FilterGroupDomainFilterFiles',
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




sub precondition
{
    my ($self) = @_;

    my $parentComposite = $self->topParentComposite();
    my $useDefault = $parentComposite->componentByName('UseDefaultDomainFilter', 1);

    return not $useDefault->useDefaultValue();
}



sub listFileDir
{
    my ($self, $row) = @_;

    my $parentRow = $self->parentRow();

    my $dir = LIST_FILE_DIR . '/' . $parentRow->valueByName('name');
    if (not -d $dir) {
        EBox::Sudo::root("mkdir -m 0755 -p $dir");
    }

    return $dir;
}






sub nameFromClass
{
    return 'FilterGroupDomainFilterFiles';
}


sub categoryForeignModel
{
    return 'FilterGroupDomainFilterCategories';
}

sub categoryForeignModelView
{
    return '/ebox/Squid/View/FilterGroupDomainFilterCategories';
}

sub categoryBackView
{
    return '/ebox/Squid/Composite/FilterGroupSettings';
}


# XXX fudge until #1280 is fixed
use EBox::Global;
sub parentComposite
{
    my ($self) = @_;
    my $dir = $self->directory();
    my $parentDir = dirname($dir);


    my $squid = EBox::Global->modInstance('squid');
    my $composite = $squid->composite('FilterGroupSettings');
    $composite->setDirectory($parentDir);
    return $composite;
}

1;

