package EBox::FileSystem;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw(makePrivateDir);

use EBox::Validate;

# Method: makePrivateDir
#
#	Creates  a  directory owned by the user running this
#	process and with private permissions.
#
# Parameters:
#
#	path - The path of the directory to be created, if it exists it must
#	       already have proper ownership and permissions.
#
# Exceptions:
#
#	Internal & External - The path exists and is not a directory or has wrong
#		   ownership or permissions. Or it does not exist and 
#		   cannot be created.
sub makePrivateDir # (path)
{
  my ($dir) = @_;


  if (-e $dir) {
    if (  not -d $dir) {
      throw EBox::Exceptions::Internal( "Cannot create private directory $dir: file exists");
    } 
    else {
      return EBox::Validate::isPrivateDir($dir, 1);
    }
  }

  mkdir($dir, 0700) or throw EBox::Exceptions::Internal("Could not create directory: $dir");

}



1;
