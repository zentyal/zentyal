package EBox::Backup::RootCommands;
# Provides the root commands used for the backup subsystem
# With the changes in sudoers this has lost sense and we may change this in the fuutres
use strict;
use warnings;

use Readonly;
Readonly::Scalar our $CDRECORD_PATH=>'/usr/bin/cdrecord';
Readonly::Scalar our $CDRDAO_PATH=>'/usr/bin/cdrdao';
Readonly::Scalar our $MKISOFS_PATH=>'/usr/bin/mkisofs';
Readonly::Scalar our $GROWISOFS_PATH=>'/usr/bin/growisofs-sudo';
Readonly::Scalar our $DVDRWFORMAT_PATH=>'/usr/bin/dvd+rw-format';
Readonly::Scalar our $DVDMEDIAINFO_PATH => '/usr/bin/dvd+rw-mediainfo';
Readonly::Scalar our $EJECT_PATH  => '/usr/bin/eject';


1;
