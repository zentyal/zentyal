# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::GConfModule;

use strict;
use warnings;

use base 'EBox::Module::Base';

use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::GConfState;
use EBox::GConfConfig;
use EBox::Types::File;
use EBox::Config::Redis;

use File::Basename;

sub _create
{
    my $class = shift;
    my %opts = @_;
    my $ro = delete $opts{ro};
    my $self = $class->SUPER::_create(@_);
    if (($self->name ne "global") && $ro) {
        $self->{ro} = 1;
    }
    bless($self, $class);
    $self->{redis} = EBox::Config::Redis->new();
    unless (defined($self->{redis})) {
        throw EBox::Exceptions::Internal("Error getting Redis client");
    }
    $self->{state} = new EBox::GConfState($self, $self->{ro});
    $self->{config} = new EBox::GConfConfig($self, $self->{ro});
    $self->{helper} = $self->{config};

    return $self;
}

sub _helper
{
    my $self = shift;
    return $self->{helper};
}

sub _config
{
    my $self = shift;
    $self->{helper} = $self->{config};
}

sub _state
{
    my $self = shift;
    $self->{helper} = $self->{state};
}

# we override aroundRestoreconfig to save gconf data before dump module config
sub aroundRestoreConfig
{
  my ($self, $dir, @extraOptions) = @_;

  $self->_load_from_file($dir);

  if ($self->isa('EBox::Model::ModelProvider')) {
    $self->restoreFilesFromArchive($dir);
  }

  $self->restoreConfig($dir, @extraOptions);
}

# load config entries from a file
sub _load_from_file
{
    my ($self, $dir, $key) = @_;
    ($dir) or $dir = EBox::Config::conf;

    $self->_config();

    my $file =  $self->_bak_file_from_dir($dir);
    if (not -f $file)  {
        EBox::error("Backup file missing for module " . $self->name);
        return;
    }

    ($key) or $key = $self->_key("");

    open(my $fh, "<$file") or EBox::error("Can't open backup file $file: $!");
    my $line = <$fh>;
    close($fh);

    return unless (defined ($line));

    # Import to /temp dir and convert paths to $key dest
    $self->{redis}->import_dir_from_file($file, '/temp');
    $self->{redis}->backup_dir('/temp/ebox/modules/' . $self->name, $key);
    $self->{redis}->delete_dir('/temp');
}


sub aroundDumpConfig
{
  my ($self, $dir, @options) = @_;
  $self->_dump_to_file($dir);

  if ($self->isa('EBox::Model::ModelProvider')) {
    $self->backupFilesInArchive($dir);
  }

  $self->dumpConfig($dir, @options);
}

# dumps GConf entries to a file in the dir specified
sub _dump_to_file
{
    my ($self, $dir) = @_;
    $self->_config();

    my $key = '/ebox/modules/' . $self->name;
    ($dir) or $dir = EBox::Config::conf;
    my $file = $self->_bak_file_from_dir($dir);
    $self->{redis}->export_dir_to_file($key, $file);
}

sub isReadOnly
{
    my $self = shift;
    return $self->{ro};
}

# Method: revokeConfig
#
#       Dismisses all changes done since the first write or delete operation.
#
sub revokeConfig
{
    my ($self) = @_;

    # No sense to revoke config on a read-only instance
    return if ($self->{ro});

    my $global = EBox::Global->getInstance();

    $global->modIsChanged($self->name) or return;

    if ($self->isa('EBox::Model::ModelProvider')) {
        $self->modelsRevokeConfig();
    }

    $self->_revokeConfigFiles();

    $global->modRestarted($self->name);

    $self->_copy_from_ro();
}

sub _saveConfig
{
    my $self = shift;
    if ($self->{ro})  {
        throw EBox::Exceptions::Internal("tried to save a read-only"
                                         . " module: " . $self->name() . "\n");
    }

    $self->_dump_to_file();

    if ($self->isa('EBox::Model::ModelProvider')) {
        $self->modelsSaveConfig();
    }

    $self->_copy_to_ro();
    $self->_saveConfigFiles();
}

sub _copy_to_ro
{
    my ($self) = @_;

    $self->_copy('ebox', 'ebox-ro');
}

sub _copy_from_ro
{
    my ($self) = @_;

    $self->_copy('ebox-ro', 'ebox');
}

sub _copy
{
    my ($self, $src, $dst) = @_;

    $self->_config();
    my $key = "/$src/modules/" . $self->name;
    $self->{redis}->backup_dir($key, "/$dst/modules/" . $self->name);
}

# TODO: remove all the low-level _change calls here if at some point everything is modelized
sub _change
{
    my ($self) = @_;

    return if ($self->{ro});

    my $global = EBox::Global->getInstance();
    $global->modChange($self->name);
}

sub _key
{
    my ($self, $key) = @_;
    return $self->_helper->key($key);
}

#############

sub st_entry_exists
{
    my ($self, $key) = @_;
    $self->_state;
    my $state = $self->get_hash('state');
    return exists $state->{$key};
}

#############

sub redis
{
	my ($self) = @_;

	return $self->{redis};
}

#############

# Method: get_bool
#
#       Returns the value of a boolean key.
#
# Parameters:
#
#       key -
#
# Returns:
#
#       boolean - key's value#
#
sub get_bool
{
    my ($self, $key) = @_;

    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key, 0);
}

sub st_get_bool
{
    my ($self, $key) = @_;

    return $self->st_get($key);
}

#############

# Method: set_bool
#
#       Sets a boolean key
#
# Parameters:
#
#       key - key to set
#       value - value
#
sub set_bool
{
    my ($self, $key, $val) = @_;

    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $val ? 1 : 0);
    $self->_change();
}

sub st_set_bool
{
    my ($self, $key, $val) = @_;

    $self->st_set($key, $val);
}

#############

# Method: get_int
#
#       Returns the value of an integer key.
#
# Parameters:
#
#       key -
#
# Returns:
#
#       integer - key's value
#
sub get_int
{
    my ($self, $key) = @_;
    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key);
}

sub st_get_int
{
    my ($self, $key) = @_;

    return $self->st_get($key);
}

#############

# Method: set_int
#
#       Sets an integer key
#
# Parameters:
#
#       key - key to set
#       val - value
#
sub set_int
{
    my ($self, $key, $val) = @_;

    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $val);
    $self->_change();
}

sub st_set_int
{
    my ($self, $key, $val) = @_;

    $self->st_set($key, $val);
}

#############

# Method: get_string
#
#       Returns the value of an string key.
#
# Parameters:
#
#       key - key name
#
# Returns:
#
#       string - key's value
#
sub get_string
{
    my ($self, $key) = @_;

    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key);
}

sub st_get_string
{
    my ($self, $key) = @_;

    return $self->st_get($key);
}

#############

# Method: set_string
#
#       Sets a string key
#
# Parameters:
#
#       key - key to set
#       value - value
#
sub set_string
{
    my ($self, $key, $val) = @_;
    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $val);
    $self->_change();
}

sub st_set_string
{
    my ($self, $key, $val) = @_;

    $self->st_set($key, $val);
}

#############

# Method: get_list
#
#       Returns the value of an string key.
#
# Parameters:
#
#       key -
#
# Returns:
#
#       It returns the list of values stored in the key .
#
#       ref to an array  - the list of values
#
sub get_list
{
    my ($self, $key) = @_;
    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key, []);
}

sub st_get_list
{
    my ($self, $key) = @_;

    return $self->st_get($key);
}

#############

sub set_hash
{
    my ($self, $key, $value) = @_;

    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $value);
}

sub get_hash
{
    my ($self, $key) = @_;

    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key, {});
}

#############

# Method: get
#
#       Returns the value of a key
#
# Parameters:
#
#       key -
#
# Returns:
#
#   Returns a <Gnome2::Gconf2::value>
#
sub get
{
    my ($self, $key) = @_;
    $self->_config;
    $key = $self->_key($key);
    return $self->redis->get($key);
}

sub st_get
{
    my ($self, $key) = @_;
    $self->_state;
    my $state = $self->get_hash('state');
    return $state->{$key};
}

# Method: set
#
#      Set an arbitrary key
#
# Parameters:
#
#       key -
#
sub set
{
    my ($self, $key, $value) = @_;
    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $value);
}

sub st_set
{
    my ($self, $key, $value) = @_;
    $self->_state;
    my $state = $self->get_hash('state');
    $state->{$key} = $value;
    $self->set('state', $state);
}

#############

# Method: unset
#
#       Unset a given key
#
# Parameters:
#
#       key -
#
#
sub unset
{
    my ($self, $key) = @_;
    $self->_config;
    $key = $self->_key($key);
    $self->redis->unset($key);
    $self->_change();
}

sub st_unset # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    my $state = $self->get_hash('state');
    delete $state->{$key};
}

#############

# Method: set_list
#
#       Sets a list of values. The type for the values is also specified
#
# Parameters:
#
#       key -
#       type - type for each value
#       values - (ref to an array) proper list of values
#
sub set_list
{
    my ($self, $key, $type, $val) = @_;
    $self->_config;
    $key = $self->_key($key);
    $self->redis->set($key, $val);
}

sub st_set_list
{
    my ($self, $key, $type, $val) = @_;

    $self->st_set($key, $val);
}

#############

# Method: delete_dir
#
#       Removes a whole directory
#
# Parameters:
#
#       key - directory to be removed
#
sub delete_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_config;
    $dir = $self->_key($dir);
    $self->redis->delete_dir($dir);
    $self->_change();
}

#############

# files stuff we have to put this stuff in gconfmodule bz if we put into models
# we lost data due to the parent/child relations

sub _filesToRemoveIfCommittedDir
{
  my ($self) = @_;
  return 'filesToRemoveIfComitted';
}


sub _filesToRemoveIfRevokedDir
{
  my ($self) = @_;
  return 'filesToRemoveIfRevoked';
}



sub addFileToRemoveIfCommitted
{
    my ($self, $file) = @_;
    my $dir = $self->_filesToRemoveIfCommittedDir();
    $self->_addFileToList($file, $dir);
}


sub addFileToRemoveIfRevoked
{
    my ($self, $file) = @_;
    my $dir = $self->_filesToRemoveIfRevokedDir();
    $self->_addFileToList($file, $dir);
}



sub _fileListDirs
{
    my ($self) = @_;

    my @dirs = (
                $self->_filesToRemoveIfCommittedDir(),
                $self->_filesToRemoveIfRevokedDir(),
             );

    return \@dirs;
}

sub _addFileToList
{
    my ($self, $file, $dir) = @_;
    my $key = $file;
    $key =~ s{/}{N1N}g; #escape path, we do not intend that we can unescape them
                        #but we need a predecible value to remove repeated keys

    # remove references to file in another lists
    my @dirs = @{ $self->_fileListDirs() };
    foreach my $listDir (@dirs) {
        my $listKey = $listDir . '/' . $key;
        $self->unset($listKey);
    }


    my $fullKey  = $dir . '/' . $key;
    $self->set_string($fullKey, $file);
}

sub _fileList
{
    my ($self, $dir) = @_;

    # FIXME: reimplement this
    return [];

    if (not $self->dir_exists($dir)) {
        return [];
    }

    my @files  = map {
        $self->get_string($_);
    } @{$self->all_entries($dir)};

    return \@files;
}

sub _saveConfigFiles
{
    my ($self) = @_;
    my $dir = $self->_filesToRemoveIfCommittedDir();
    $self->_removeFilesFromList($dir);
}


sub _clearFilesToRemoveLists
{
  my ($self) = @_;

    # FIXME: reimplement this
    return;

  my @dirs = @{ $self->_fileListDirs() };

  foreach my $dir (@dirs) {
      if ($self->dir_exists($dir)) {
          $self->delete_dir($dir);
      }
  }

}

sub _revokeConfigFiles
{
    my ($self) = @_;

    my $dir = $self->_filesToRemoveIfRevokedDir();
    $self->_removeFilesFromList($dir);
}

sub _removeFilesFromList
{
    my ($self, $dir) = @_;

    my @files = @{ $self->_fileList($dir) };
    foreach my $file ( @files  ) {
        my $backupPath         = EBox::Types::File->backupPath($file);
        my $noPreviousFilePath = EBox::Types::File->noPreviousFilePath($file);

        EBox::Sudo::root("rm -rf '$file' '$backupPath' '$noPreviousFilePath'");
    }

    $self->_clearFilesToRemoveLists();
}

1;
