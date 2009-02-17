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
use strict;
use warnings;

package EBox::MailFilter::Model::FileExtensionACL;
use base 'EBox::Model::DataTable';
# Class:
#
#    EBox::Mail::Model::ObjectPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::MailFilter::Types::FileExtension;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
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
#       The table description 
#
sub _table
{
  my @tableHeader =
    (
     new EBox::MailFilter::Types::FileExtension(
                             fieldName     => 'extension',
                             printableName => __('File extension'),
                             unique        => 1,
                             editable      => 1,
                            ),
     new EBox::Types::Boolean(
                                    fieldName     => 'allow',
                                    printableName => __('Allow'),
                                    editable      => 1,
                                   ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{File extensions}),
     modelDomain        => 'mail',
     'defaultController' => '/ebox/MailFilter/Controller/FileExtensionACL',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __("file extension"),
     help               => __("Extensions which are not listed below are allowed"),
     pageSize           => 5,
    };

}



# Method: banned
#
# Returns:
#   - reference to a list of banned extensions
# 
sub banned
{
    my ($self) = @_;
    my @banned;
    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        unless ($row->valueByName('allow')) {
            push (@banned, $row->valueByName('extension'));
        }
    } 
    return \@banned;
}


sub bannedRegexes
{
  my ($self) = @_;

  my @bannedExtensions = @{  $self->banned };
  @bannedExtensions = map { '^.' . $_ . '$'  } @bannedExtensions;

  return \@bannedExtensions;
}



1;

