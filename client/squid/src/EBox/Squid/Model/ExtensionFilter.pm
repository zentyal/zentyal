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

package EBox::Squid::Model::ExtensionFilter;
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
#       <EBox::Squid::Model::ExtensionFilter> - the recently
#       created model
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless $self, $class;
      return $self;

  }

sub validateTypedRow
{
  my ($self, $action, $params_r) = @_;

  if (exists $params_r->{extension} ) {
    my $extension = $params_r->{extension}->value();
    if ($extension =~ m{\.}) {
        throw EBox::Exceptions::InvalidData(
                data  => __('File extension'),
                value => $extension,
                advice => ('Dots (".") are not allowed in file extensions')
                )
    }
  }

}


# Function: bannedExtensions
#
#	Fetch the banned extensions
#
# Returns:
#
# 	Array ref - containing the extensions
sub banned
{
  my ($self) = @_;
  
  my @bannedExtensions;

  for my $row (@{$self->rows()}) {
    if (not $row->valueByName('allowed')) {
        push (@bannedExtensions, $row->valueByName('extension'));
    }
  }
  return \@bannedExtensions;
}

# Group: Protected methods


sub _table
{
    my ($self) = @_;
    my $warnMsg = q{The extension filter needs a 'filter' policy to take effect};



  my $dataTable =
    {
     tableName          => 'ExtensionFilter',
     printableTableName => __('Configure allowed file extensions'),
     modelDomain        => 'Squid',
     defaultController  => '/ebox/Squid/Controller/ExtensionFilter',
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

1;

