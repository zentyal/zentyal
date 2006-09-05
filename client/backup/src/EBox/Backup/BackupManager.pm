package EBox::Backup::BackupManager;
# Description: Module to control the Backup Manager program 
use strict;
use warnings;
use English qw(-no_match_vars);
use EBox::Config;
use EBox::Gettext;
use EBox::Sudo;
use HTML::Mason;
use Error qw(:try);

use Readonly;
Readonly::Scalar my  $CONF_FILE => 'backup-manager.conf';
Readonly::Scalar my  $CONF_FILE_TEMPLATE => '/backup/backup-manager.conf.mas';


sub backup
{
  my (%params) = @_;

  my $bin = delete  $params{bin};

  writeConfFile(%params);

  my $command = backupCommand($bin);
  my @output = `$command`;
  if ($? != 0) {
    throw EBox::Exceptions::External (__x("backup-manager failed. Command {command}. Output {output}", command => $command, output => "@output"));
  }
}

sub backupCommand
{
  my ($bin) = @_;
  my $command =  "$bin --verbose --conffile " . confFile();
  return $command;
}


sub writeConfFile
{
  my (@params) = @_;
  
  my $confFile = confFile();
  my $oldUmask = umask;

  try {
    umask 0077;
    open my $FH, ">$confFile";

    my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::stubs,
					out_method => sub { $FH->print($_[0]) });
    my $comp = $interp->make_component(comp_file =>
				       EBox::Config::stubs . "/" . $CONF_FILE_TEMPLATE);
    $interp->exec($comp, @params);
    $FH->close();
  }
  finally {
    umask $oldUmask;
  };

}


sub confFile
{
  my $file = EBox::Config::tmp() . "/$CONF_FILE";
  return $file;
}


1;
