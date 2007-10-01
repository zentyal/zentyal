package EBox::CGI::Temp;
# Package: EBox::CGI::Temp
#
#   this packages contain methods to manage temporal www data, like generated images
use strict;
use warnings;

use EBox::Config;
use File::Temp;
use File::Basename;



sub urlImagesDir
{
  return '/dynamic-data/images/';
}


#  Function: newImage
#
#   create a empty temporal file in the images directory. The file is empty and
#   the user must overwrite it with a image file. 
#    Before creating the files the
#   clean() function is called to cleanup old files
#
#    Returns:
#        a hash which the following keys
#            file - fiel path to the temporal file
#            url - URL used to address the file from a web page
#
sub newImage
{
  cleanImages();

  my ($fh, $file) = File::Temp::tempfile(DIR => EBox::Config::dynamicimages());
  close $fh;  
 
  my  $url = urlImagesDir() . basename $file;

  return {
	  file => $file,
	  url  => $url,

	 };
}

#  Function: cleanImages
#
#  remove older than 300 second images files
sub cleanImages
{
  my $currentTime = time();
  my $livingInterval = 300;

  my $dir = EBox::Config::dynamicimages();

  my $DH;
  opendir $DH, $dir;
  while (my $f = readdir $DH) {
    my $path = "$dir/$f";
    my @stat = stat $path;
    my $mtime =$stat[9];
    if (($currentTime - $mtime) > $livingInterval) {
      unlink $path;
    }

  }
  closedir $DH;
}



1;

