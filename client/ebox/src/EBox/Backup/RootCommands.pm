package EBox::Backup::RootCommands;
# Provides the root commands used for the backup subsystem
use strict;
use warnings;

use Readonly;
Readonly::Scalar our $CDRECORD_PATH=>'/usr/bin/cdrecord';
Readonly::Scalar our $MKISOFS_PATH=>'/usr/bin/mkisofs';
Readonly::Scalar our $GROWISOFS_PATH=>'/usr/bin/growisofs-sudo';
Readonly::Scalar our $DVDRWFORMAT_PATH=>'/usr/bin/dvd+rw-format';
Readonly::Scalar our $DVDMEDIAINFO_PATH => '/usr/bin/dvd+rw-mediainfo';
Readonly::Scalar our $EJECT_PATH  => '/usr/bin/eject';

sub rootCommands
{
  my @commands =  (
		   $CDRECORD_PATH,
		   $MKISOFS_PATH,
		   $GROWISOFS_PATH,
		   $DVDRWFORMAT_PATH,
		   $DVDMEDIAINFO_PATH,
		   $EJECT_PATH,
    );
  return @commands;
}




1;
