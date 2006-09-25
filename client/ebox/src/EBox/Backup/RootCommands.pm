package EBox::Backup::RootCommands;
# Provides the root commands used for the backup subsystem
use strict;
use warnings;


sub rootCommands
{
  my @commands =  (
   '/usr/bin/cdrecord',
   '/usr/bin/dvd+rw-mediainfo',
   '/usr/bin/eject',
   '/usr/bin/growisofs-sudo',
    );
  return @commands;
}




1;
