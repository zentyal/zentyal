# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Backup;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use Error qw(:try);
use File::Slurp  qw(write_file);
use EBox::Summary::Module;

use Readonly;
Readonly::Scalar my $GCONF_DUMP_COMMAND => '/usr/bin/gconftool-2 --dump /ebox';
Readonly::Scalar my $GCONF_LOAD_COMMAND => '/usr/bin/gconftool-2 --load ';
Readonly::Scalar my $GCONF_DUMP_FILE     => 'gconf.xml';


sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'backup');
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
}



sub rootCommands
{
	my $self = shift;
	my @commands = ();
	return @commands;
}

sub backupDir
{
  warn "Provisional";
  return EBox::Config::tmp() . '/backup';
}





sub backupGConf
{
  my ($self) = @_;

  my $dir = $self->backupDir();
  my $oldUmask = umask();

  try {
    umask '0077';

    my @dumpOutput = `$GCONF_DUMP_COMMAND`;
    if ($? != 0) {
      throw EBox::Exceptions::External (__("Error backing up GConf: @dumpOutput"));
    }

    write_file("$dir/$GCONF_DUMP_FILE", \@dumpOutput);
  }
  finally {
    umask $oldUmask;
  };
}


sub restoreGConf
{
  my ($self) = @_;

  my $dir = $self->backupDir();
  my $loadOutput =  `$GCONF_LOAD_COMMAND $dir/$GCONF_DUMP_FILE`;

  if ($? != 0) {
    throw EBox::Exceptions::External (__('Error restoring EBox GConf: ') . $loadOutput);
  }
}


sub backup
{
  #my @mods =  grep { $_->can('backupHelper')   }   @{ EBox::Global->modInstances() }; 

  backupGConf();

}


sub restore
{
  restoreGConf();
}



sub summary
{
	my $self = shift;
	my $item = new EBox::Summary::Module(__("Configuration backup"));
	return $item;
}
1;
