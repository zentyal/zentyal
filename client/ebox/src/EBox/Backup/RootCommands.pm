package EBox::Backup::RootCommands;
# Provides the root commands used for the backup subsystem
use strict;
use warnings;


sub rootCommands
{
  my @commands = qw(/usr/bin/cdrecord /usr/bin/dvd+rw-mediainfo);
  return @commands;
}

1;
