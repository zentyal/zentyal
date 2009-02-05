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

package EBox::Squid::Model::FilterGroupExtensionFilter;
use base 'EBox::Squid::Model::ExtensionFilterBase';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;


# Group: Public methods


sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless $self, $class;
      return $self;
  }

sub _table
{
    my ($self) = @_;
  my $warnMsg = q{The extension filter needs a 'filter' policy to take effect};


  my $dataTable =
    {
     tableName          => 'FilterGroupExtensionFilter',
     printableTableName => __('Configure allowed file extensions'),
     modelDomain        => 'Squid',
     defaultController  => '/ebox/Squid/Controller/FilterGroupExtensionFilter',
     defaultActions     =>
     [	
      'add', 'del',
      'editField',
      'changeView'
     ],
     tableDescription   => $self->_tableHeader(),
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __('extension'),
     help               => __("Allow/Deny the HTTP traffic of the files which the given extensions.\nExtensions not listed here are allowed.\nThe extension filter needs a 'filter' policy to be in effect"),

     messages           => {
                            add    => __('Extension added'),
                            del    => __('Extension removed'),
                            update => __('Extension updated'),
                           },
     sortedBy           => 'extension',
    };

}

sub precondition
{
    my ($self) = @_;

    my $parentComposite = $self->topParentComposite();
    my $useDefault = $parentComposite->componentByName('UseDefaultExtensionFilter', 1);

    return not $useDefault->useDefaultValue();
}



sub preconditionFailMsg
{
    return __('Using default profile configuration');
}

1;

