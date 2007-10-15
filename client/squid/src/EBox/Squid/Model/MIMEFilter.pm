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

# Class:
#
#    EBox::Squid::Model::ExtensionsFilter
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


use Perl6::Junction qw(all);

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
#       <EBox::Squid::Model::MIMEFilter - the recently
#       created model
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless  $self, $class;
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
  my @tableHeader =
    (
     new EBox::Types::Text(
			   fieldName     => 'MIMEType',
			   printableName => __('MIME Type'),
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
     tableDescription   => \@tableHeader,
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
    };

}

sub validateTypedRow
{
  my ($self, $action, $params_r) = @_;

  if (exists $params_r->{MIMEType} ) {
    my $type = $params_r->{MIMEType}->value();
    $self->checkMimeType($type);
  }

}

# Function: bannedMimeTypes
#
#	Fetch the banned MIME types
#
# Returns:
#
# 	Array ref - containing the MIME types
sub banned
{
  my ($self) = @_;
  
  my @banned = map {
    my $values = $_->{plainValueHash};
    if ($values->{allowed}) {
      ();
    } else {
      ($values->{MIMEType});
    }
  } @{ $self->rows() };
		   
  return \@banned;
}





#       A MIME type follows this syntax: type/subtype
#       The current registrated types are: <http://www.iana.org/assignments/media-types/index.html>
#
my @ianaMimeTypes = ("application",
	       "audio",
	       "example",
	       "image",
	       "message",
	       "model",
	       "multipart",
	       "text",
	       "video",
	       "[Xx]-.*" );
my $allIanaMimeType = all @ianaMimeTypes;
  

sub checkMimeType
{
  my ($self, $type) = @_;

  my ($mainType, $subType) = split '/', $type, 2;

  if (not defined $subType) {
    throw EBox::Exceptions::InvalidData(
					data  => __('MIME Type'),
					value => $type,
					advice => __('A MIME Type must follows this syntax: type/subtype'),
				       )
  }


  if ($mainType ne $allIanaMimeType) {
    throw EBox::Exceptions::InvalidData(
					data  => __('MIME Type'),
					value => $type,
					advice => __x(
						      '{type} is not a valid IANA type',
						      type => $mainType,
						     )
				       )
  }

  if (not $subType =~ m{^[\w\-\d]+$} ) {
    throw EBox::Exceptions::InvalidData(
					data   => __('MIME Type'),
					value  => $type,
					advice => __x(
						      '{t} subtype has a wrong syntax',
						      t => $subType,
						     )
				       )
  }


  return 1;
}





1;

