#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
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

#
#   gconf changes: filterSettigns data moved to default profile data
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

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

        my $value = $mod->get($oldEntry);
        $mod->set($newEntry, $value);
        $mod->unset($oldEntry);
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
