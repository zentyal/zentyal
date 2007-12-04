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

# Class: EBox::Model::DataForm::Image
#
#       An specialized model from <EBox::Model::DataForm> which
#       includes a image or a graphic. 

package EBox::Model::Image;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::CGI::Temp;

sub new
{

  my $class = shift @_;
  
  my $self = $class->SUPER::new(@_);
  
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







sub addRow
  {
      throw EBox::Exceptions::Internal('It is not possible to add a row to ' .
                                       'a image model');

  }


sub addTypedRow
{

    throw EBox::Exceptions::Internal('It is not possible to add a row to ' .
                                     'a image model');

}



sub setRow
{
    throw EBox::Exceptions::Internal('Forbidden action in ' .
                                     'a image model');
}

sub setTypedRow
{
    throw EBox::Exceptions::Internal('Forbidden action in ' .
                                     'a image model');
}


sub set
{
    throw EBox::Exceptions::Internal('Forbidden action in ' .
                                     'a image model');
}

1;
