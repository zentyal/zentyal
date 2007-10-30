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

  my $openvpn = $self->{gconfmodule};
  my @clientDirs = $openvpn->all_dirs('client');
  foreach my $clientDir (@clientDirs) {
    my $caCertificatePathKey   =  "$clientDir/caCertificatePath";
    my $caCertificatePathValue = $openvpn->get_string($caCertificatePathKey);
    if (defined $caCertificatePathValue) {
      $self->_updateCertificatePath($caCertificatePathKey, $caCertificatePathValue)
    }

    my $certificatePathKey   =  "$clientDir/certificatePath";
    my $certificatePathValue = $openvpn->get_string($certificatePathKey);
    if (defined $certificatePathValue) {
      $self->_updateCertificatePath($certificatePathKey, $certificatePathValue)
    }

  }

}

sub _updateCertificatePath
{
  my ($self, $pathKey, $pathValue) = @_;
  my $openvpn = $self->{gconfmodule};

  # the new key and values hasn't the Path subfix
  my $newKey = $pathKey;
  $newKey =~ s/Path$//;
  if ($newKey eq $pathKey) {
    # nothing to do
    return;
  }

  my $newPath = $pathValue;
  $newPath =~ s/Path//;

  $openvpn->set_string($newKey, $newPath);
  $openvpn->unset($pathKey);

  if ($newPath eq $pathValue) {
    # nothing more to do
    return;
  }
  
  if (not EBox::Sudo::fileTest('-f', $pathValue)) {
    # no old file, so nothing to do
    EBox::warning("Certificate file $pathValue not found for openvpn client.");
    return;
  }

  if (EBox::Sudo::fileTest('-f', $newPath)) {
    EBox::warning("Certificate file $newPath for openvpn client already exists" );
    return;
  }
  

  my $mvCommand = "/bin/mv $pathValue $newPath";
  EBox::Sudo::root($mvCommand);

}




sub _changeLogFiles
{
  my ($self) = @_;
  my $openvpn = $self->{gconfmodule};
  my @daemons = $openvpn->daemons();

  my $oldLogDir = EBox::Config::log();

  my $DIR_H;
  opendir $DIR_H, $oldLogDir;

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
				     'version' => 2
				    );
$migration->execute();				     


1;
