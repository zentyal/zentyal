#!/usr/bin/perl

#
#   gconf changes: filterSettigns data moved to default profile data
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

use Perl6::Junction qw(any all);

my $defaultProfileDir = 'FilterGroup/defaultFilterGroup/filterPolicy';

sub runGConf
{
  my ($self) = @_;

  $self->_migrateThreshold();
  $self->_migrateDomains();
  $self->_migrateExtensions();
  $self->_migrateMIMETypes();
}




sub _migrateThreshold
{
    my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $oldDir = 'ContentFilterThreshold';
  my $newDir = "$defaultProfileDir/ContentFilterThreshold/keys";

  if ($squid->dir_exists($oldDir)) {
      $self->_moveGConfDir($squid, $oldDir, $newDir);
  } 
}


sub _moveGConfDir
{
    my ($self, $mod, $oldDir, $newDir) = @_;

    foreach my $subdir ( @{ $mod->all_dirs_base($oldDir) } ) {
        my $oldSubDir = $oldDir . '/' . $subdir;
        my $newSubdir = $newDir . '/' . $subdir;
        $self->_moveGConfDir($mod, $oldSubDir, $newSubdir);
    }

    foreach my $entry (@{ $mod->all_entries_base($oldDir) }) {
        my $modDir   = '/ebox/modules/' . $mod->name();
        my $oldEntry = $modDir . '/' . $oldDir . '/' . $entry;
        my $newEntry = $modDir . '/' . $newDir . '/' . $entry;

        my $gclient = Gnome2::GConf::Client->get_default;
        my $value = $gclient->get($oldEntry);
        $gclient->set($newEntry, $value);
        $gclient->unset($oldEntry);
    }
}


sub _migrateDomains
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $oldDir = 'DomainFilter';
  my $newDir =  "$defaultProfileDir/DomainFilter";

  if ($squid->dir_exists($oldDir)) {
      $self->_moveGConfDir($squid, $oldDir, $newDir);
  } 

  my $oldSettingsDir = 'DomainFilterSettings';
  my $newSettingsDir =  "$defaultProfileDir/DomainFilterSettings/keys";
  if ($squid->dir_exists($oldSettingsDir)) {
      $self->_moveGConfDir($squid, $oldSettingsDir, $newSettingsDir);
  } 
}

sub _migrateExtensions
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $oldDir = 'ExtensionFilter';
  my $newDir =  "$defaultProfileDir/ExtensionFilter";

  if ($squid->dir_exists($oldDir)) {
      $self->_moveGConfDir($squid, $oldDir, $newDir);
  } 
}




sub _migrateMIMETypes
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};  

  my $oldDir = 'MIMEFilter';
  my $newDir =  "$defaultProfileDir/MIMEFilter";

  if ($squid->dir_exists($oldDir)) {
      $self->_moveGConfDir($squid, $oldDir, $newDir);
  }
}





EBox::init();
my $squid = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $squid,
                                     'version' => 3,
                                    );
$migration->execute();                               


1;
