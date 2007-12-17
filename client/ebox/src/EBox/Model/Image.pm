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

# Class: EBox::Model::Image
#
#       An specialized model from <EBox::Model::DataForm> which
#       includes a image or a graphic. 

package EBox::Model::Image;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::CGI::Temp;

sub new
{

  my ($class, @params) =  @_;
  
  my $self = $class->SUPER::new(@params);
  
  bless ( $self, $class );
  

  
  return $self;
  
}


sub Viewer
{
  return '/ajax/image.mas';
}


sub image
{
  my ($self) = @_;

  my $image_r = EBox::CGI::Temp::newImage();
  $self->_generateImage($image_r->{file});


  return $image_r->{url};
}


sub imageAlt
{
  return '';
}

# to override by subclass
sub _generateImage
{
  throw EBox::Exceptions::NotImplemented();
}



sub _setDefaultMessages
{

    my ($self) = @_;

    # Table is already defined
    my $table = $self->{'table'};

    $table->{'messages'} = {} unless ( $table->{'messages'} );
    my $rowName = $self->printableRowName();

    my %defaultMessages =
      (
       'add'       => undef,
       'del'       => undef,
       'update'    => undef,
       'moveUp'    => undef,
       'moveDown'  => undef,
      );

    foreach my $action (keys (%defaultMessages)) {
        unless ( exists $table->{'messages'}->{$action} ) {
            $table->{'messages'}->{$action} = $defaultMessages{$action};
        }
    }
}







1;
