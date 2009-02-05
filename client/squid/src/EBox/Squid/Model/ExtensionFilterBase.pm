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

package EBox::Squid::Model::ExtensionFilterBase;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;




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
#       Fetch the banned extensions
#
# Returns:
#
#       Array ref - containing the extensions
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


sub _tableHeader
{

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
 
                              optional      => 0,
                              editable      => 1,
                              defaultValue  => 1,
                             ),
    );

   return \@tableHeader;
}

1;

