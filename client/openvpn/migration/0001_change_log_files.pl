#!/usr/bin/perl

#  Migration between gconf data version 1 and 2
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

use Fatal qw(opendir readdir closedir);


sub runGConf
{
  my ($self) = @_;

  $self->_changeLogFiles();
}




sub _changeLogFiles
{
  my ($self) = @_;
  my $openvpn = $self->{gconfmodule};
  my @daemons = $openvpn->daemons();

  my $oldLogDir = EBox::Config::log();

  my $DIR_H;
  opendir $DIR_H, $oldLogDir or return;

  while  (1) {
    my $file;
    eval {
      $file = readdir($DIR_H)
    };
    if ($@) {
      EBox::error("problem reading directory for migration script: $@");
      last;
    }

    defined $file or last;

    if ($file =~ m/^openvpn-(.*)\.log$/) {
      my $iface = $1;

      my ($daemon) = grep {  $_->iface eq $iface } @daemons;
      if ($daemon) {
	my $origPath = $oldLogDir . '/' . $file;
	my $newPath  = $daemon->logFile();
	EBox::Sudo::root("mv $origPath $newPath");
	EBox::debug("old log file $origPath moved to $newPath");
      }
      else {
	EBox::debug("No daemon candidate found for file $file. Leaving it as is");
      }
    }
  }


  closedir $DIR_H;
}





EBox::init();
my $openvpn = EBox::Global->modInstance('openvpn');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $openvpn,
				     'version' => 1
				    );
$migration->execute();				     


1;
