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



# returns a hash with the following:
#      uri - image uri
#      alt - alt text for image 
#        - or -
#      error - error message to print instead of image  
sub image
{
  my ($self) = @_;

  my $imageFile_r = EBox::CGI::Temp::newImage();

  my $generatedImage_r =   $self->_generateImage($imageFile_r->{file});
  
  # add default alt if needed
  exists $generatedImage_r->{alt} or 
    $generatedImage_r->{alt} = '';
  exists $generatedImage_r->{error} or
    $generatedImage_r->{error} = 'No image available';

  if ($generatedImage_r->{image}) {
    return {
	    url => $imageFile_r->{url},
	    alt => $generatedImage_r->{alt},
	   }
  }
  else {
    return {
	    error => $generatedImage_r->{error},
	   }
  }

}




# to override by subclass
# must return a hash with the following:
#      image - wether the image was created or not
#      alt - alt text for image (optional)
#      error - error message to print instead of image  (optional)
#     
sub _generateImage
{
  throw EBox::Exceptions::NotImplemented();
}






# must return the ImageControl subclass associated with the image
sub _controlModel
{
  throw EBox::Exceptions::NotImplemented;
}


sub _controlModelField
{
  my ($self, $field) = @_;
  my $control = $self->_controlModel;

  my $getter = $field . 'Value';
  return $control->$getter;
}


# Method: checkTable
#
#  This method does some fast and general checks in the table specification
#  We override it bz for Images is acceptable to not have elements in the tableDescription
#
#  Override: <EBox::Model::DataTable>
sub checkTable
{
    my ($self, $table) = @_;

    if (not exists $table->{tableDescription}) {
        throw EBox::Exceptions::Internal('Missing tableDescription in table definition');
    }

    
    if (not $table->{tableName}) {
        throw EBox::Exceptions::Internal(
            'table description has not tableName field or has a empty one'
                                        );
      }

    if ((exists $table->{sortedBy}) and (exists $table->{order})) {
        if ($table->{sortedBy}and $table->{order}) {
            throw EBox::Exceptions::Internal(
             'sortedBy and order are incompatible options'
                                        );
        }
    }


    
}

# Method: refreshImage
#
#   signal wether the image msut be periodically refreshed or not
#
#    Defaults: true
sub refreshImage
{
    my ($self) = @_;
    return 1;
}


1;
