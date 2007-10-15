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

# Class:
#
#    EBox::Squid::Model::ExtensionFilter
#
#
#   It subclasses <EBox::Model::DataTable>
#

use base 'EBox::Model::DataTable';

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

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name          - <EBox::Types::Text>
#       description   - <EBox::Types::Text>
#       configuration - <EBox::Types::Union>. It could have one of the following:
#                     - model - <EBox::Types::HasMany>
#                     - link  - <EBox::Types::Link>
#                     - none  - <EBox::Types::Union::Text>
#       enabled       - <EBox::Types::Boolean>
#
#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
#
sub _table
{

  my $warnMsg = q{The extension filter needs a 'filter' policy to take effect};


  my @tableHeader =
    (
     new EBox::Types::Text(
			   fieldName     => 'extension',
			   printableName => __('Extension'),
			   unique        => 1,
			   editable      => 1,
			   optional      => 0,
			  ),
     new EBox::Types::Boolean(
			      fieldName     => 'allowed',
			      printableName => __('Allow'),
 
			      optional      => 1,
			      editable      => 1,
			      defaultValue  => 1,
			     ),
    );

  my $dataTable =
    {
     tableName          => 'ExtensionFilter',
     printableTableName => __('Configure allowed file extensions'),
     modelDomain        => 'Squid',
     'defaultController' => '/ebox/Squid/Controller/ExtensionFilter',
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
     printableRowName   => __('extension'),
     help               => __("Allow/Deny the HTTP traffic of the files which the given extensions.\nExtensions not listed here are allowed.\nThe extension filter needs a 'filter' policy to be in effect"),

     messages           => {
			    add    => __('Extension added'),
			    del    => __('Extension removed'),
			    update => __('Extension updated'),
			   },
    };

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
  
  my @bannedExtensions = map {
    my $values = $_->{plainValueHash};
    if ($values->{allowed}) {
      ();
    } else {
      ($values->{extension});
    }
  } @{ $self->rows() };
		   
  return \@bannedExtensions;
}


1;

