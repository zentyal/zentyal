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
use File::Basename;
use EBox::Types::File;
use EBox::Config::Redis;

sub _create # (name)
{
    my $class = shift;
    my %opts = @_;
    my $ro = delete $opts{ro};
    my $self = $class->SUPER::_create(@_);
    my $ebox = "ebox";
    if (($self->name ne "global") && $ro) {
        $self->{ro} = 1;
        $ebox = "ebox-ro";
    }
    bless($self, $class);
    $self->{redis} = EBox::Config::Redis->new();
    unless (defined($self->{redis})) {
        throw EBox::Exceptions::Internal("Error getting Redis client");
    }
    $self->{state} = new EBox::GConfState($self, $self->{ro});
    $self->{config} = new EBox::GConfConfig($self, $self->{ro});
    $self->{helper} = $self->{config};
    if ($self->name ne "global" && $ro) {
        my $global = EBox::Global->getInstance($ro);
        unless ($global->modIsChanged($self->name)) {
            $self->_dump_to_file;
        }
        $self->_load_from_file;
    }

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


sub initChangedState
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    $global->modIsChanged($self->name) and
        throw EBox::Exceptions::Internal($self->name .
                                          ' module already has changed state');

    $self->_dump_to_file();
}



# we override aroundRestoreconfig to save gconf data before dump module config
sub aroundRestoreConfig
{
  my ($self, $dir) = @_;

  $self->_load_from_file($dir);

  if ($self->isa('EBox::Model::ModelProvider')) {
    $self->restoreFilesFromArchive($dir);
  }

  $self->restoreConfig($dir);
}

# load GConf entries from a file
sub _load_from_file # (dir?, key?)
{
    my ($self, $dir, $key) = @_;
    ($dir) or $dir = EBox::Config::conf;

    $self->_config();

    my $file =  $self->_bak_file_from_dir($dir);
    if (not  -f $file)  {
        EBox::error("Backup file missing for module " . $self->name);
        return;
    }

    ($key) or $key = $self->_key("");

    open(FILE, "< $file") or EBox::error("Can't open backup file $file: $!");
    my $line = <FILE>;
    close(FILE);

    return unless (defined($line));

    if ( $line =~ /^</ ) {
        # Import from GConf
        EBox::debug("Old gconf format detected");
        $self->{redis}->import_dir_from_gconf($file);
    } else {
        # YAML file
        # Import to /temp dir and convert paths to $key dest
        $self->{redis}->import_dir_from_yaml($file, '/temp');
        $self->{redis}->backup_dir('/temp/ebox/modules/' . $self->name, $key);
        $self->{redis}->delete_dir('/temp');
    }


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
sub _dump_to_file # (dir?)
{
    my ($self, $dir) = @_;
    $self->_config();

    my $key = '/ebox/modules/' . $self->name;
    ($dir) or $dir = EBox::Config::conf;
    my $file = $self->_bak_file_from_dir($dir);
    $self->{redis}->export_dir_to_yaml($key, $file);
}


# we had to call _backup before continue the normal restoreBackup process
sub restoreBackup
{
  my $self = shift;
  $self->_backup();

  $self->SUPER::restoreBackup(@_);
}

sub isReadOnly
{
    my $self = shift;
    return $self->{ro};
}

#
# Method: revokeConfig
#
#       Dismisses all changes done since the first write or delete operation.
#
sub revokeConfig
{
    my $self = shift;
    my $global = EBox::Global->getInstance();

    $global->modIsChanged($self->name) or return;

    if ($self->isa('EBox::Model::ModelProvider')) {
        $self->modelsRevokeConfig();
    }

    $self->_revokeConfigFiles();

    $global->modRestarted($self->name);

    my $ro = $self->{ro};
    $self->{ro} = undef;
    $self->_load_from_file();

    $self->{ro} = $ro;
}


sub scheduleRestart
{
    my $self = shift;
    $self->_backup;
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

    $self->_config();
    my $key = "/ebox/modules/" . $self->name;
    $self->{redis}->backup_dir($key, '/ebox-ro/modules/' . $self->name);
}

sub _backup
{
    my $self = shift;
    $self->_helper->backup();
}

# Returns:
#
#       Gnome2::GConf object
#
sub gconf
{
    my $self = shift;
    EBox::debug("Deprecated");
}

sub _key # (key)
{
    my ($self, $key) = @_;
    return $self->_helper->key($key);
}
#############

sub _entry_exists # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    return $self->{redis}->exists($key);
}

# Method: entry_exists
#
#       Given a key referencing an entry tells you if it exists
#
# Parameters:
#
#       key - entry key
#
# Returns:
#
#       boolean - True if it exists
#
sub entry_exists # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_entry_exists($key);
}

sub st_entry_exists # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_entry_exists($key);
}

#############

sub _dir_exists # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    return $self->{redis}->dir_exists($key);
}

# Method: dir_exists
#
#       Given a key referencing a directory tells you if it exists
#
# Parameters:
#
#       key - directory's key
#
# Returns:
#
#       boolean - True if it exists
#
sub dir_exists # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_dir_exists($key);
}

sub st_dir_exists # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_dir_exists($key);
}

#############

sub _all_dirs_base # (key)
{
    my ($self, $key) = @_;
    my @array = $self->_all_dirs($key);
    my @names = ();
    foreach (@array) {
        push(@names, basename($_));
    }
    return \@names;
}

sub all_dirs_base # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_all_dirs_base($key);
}

sub st_all_dirs_base # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_all_dirs_base($key);
}

#############

sub _all_entries_base # (key)
{
    my ($self, $key) = @_;
    my @array = @{$self->_all_entries($key)};
    my @names = ();
    foreach (@array) {
        push(@names, basename($_));
    }
    return \@names;
}

#
# Method: all_entries_base
#
#       Given a key it returns all directories within, removing
#       any leading directory component.
#
# Parameters:
#
#       key
#
# Returns:
#
#       ref to an array of strings - each string represents an entry
#
sub all_entries_base # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_all_entries_base($key);
}

sub st_all_entries_base # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_all_entries_base($key);
}

#############
sub redis {
	my ($self) = @_;
	return $self->{redis};
}
sub _all_dirs # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    my @ret = @{$self->redis->all_dirs($key)};
    unless (@ret) {
        @ret = ();
    }
    return @ret;
}

#
# Method: all_dirs
#
#       Given a key it returns all directories within.
#
# Parameters:
#
#       key - directory's key
#
# Returns:
#
#       array  of strings - Each string contains a directory
#
sub all_dirs # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_all_dirs($key);
}

sub st_all_dirs # (key)
{
    my ($self, $key) = @_;
        $self->_state;
    return $self->_all_dirs($key);
}

#############

sub _all_entries # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    my @entries = @{$self->redis->all_entries($key)};
    return \@entries;
}

#
# Method: all_entries
#
#       Given a key it returns all entries within. Entries are all
#       those keys which are not directories, hence they contain a value
#
# Parameters:
#
#       key -
#
# Returns:
#
#       A ref to an array of strings - Each string contains an entry
#
#
sub all_entries # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_all_entries($key);
}

sub st_all_entries # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_all_entries($key);
}

#############

sub _get_bool # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    my $value = $self->redis->get_bool($key);
    if($value) {
        return 1;
    } else {
        return 0;
    }
}

#
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
sub get_bool # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_get_bool($key);
}



sub st_get_bool # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_get_bool($key);
}

#############

sub _set_bool # (key, value)
{
    my ($self, $key, $val) = @_;
    $key = $self->_key($key);
    $self->_backup;
    $self->redis->set_bool($key, $val);
}

#
# Method: set_bool
#
#       Sets a boolean key
#
# Parameters:
#
#       key - key to set
#       value - value
#
sub set_bool # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_config;
    $self->_set_bool($key, $val);
}

sub st_set_bool # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_state;
    $self->_set_bool($key, $val);
}

#############

sub _get_int # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    my $value = $self->redis->get_int($key);
    return $value;
}

#
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
sub get_int # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_get_int($key);
}

sub st_get_int # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_get_int($key);
}

#############

sub _set_int # (key, value)
{
    my ($self, $key, $val) = @_;
    $key = $self->_key($key);
    $self->_backup;
    $self->redis->set_int($key, $val);
}

#
# Method: set_int
#
#       Sets an integer key
#
# Parameters:
#
#       key - key to set
#       value - value
#
sub set_int # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_config;
    $self->_set_int($key, $val);
}

sub st_set_int # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_state;
    $self->_set_int($key, $val);
}

#############

sub _get_string # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    return $self->redis->get_string($key);
}

#
# Method: get_string
#
#       Returns the value of an string key.
#
# Parameters:
#
#       key -
#
# Returns:
#
#       string - key's value
#
sub get_string # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_get_string($key);
}

sub st_get_string # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_get_string($key);
}

#############

sub _set_string # (key, value)
{
    my ($self, $key, $val) = @_;
    $key = $self->_key($key);
    $self->_backup;
    $self->redis->set_string($key, $val);
}

#
# Method: set_string
#
#       Sets a string  key
#
# Parameters:
#
#       key - key to set
#       value - value
#
sub set_string # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_config;
    $self->_set_string($key, $val);
}

sub st_set_string # (key, value)
{
    my ($self, $key, $val) = @_;
    $self->_state;
    $self->_set_string($key, $val);
}

#############

sub _get_list # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    my $list = $self->redis->get_list($key);
    if ($list) {
        return $list;
    } else {
        return [];
    }
}

#
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
sub get_list # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_get_list($key);
}

sub st_get_list # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_get_list($key);
}

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
sub get # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    return $self->_get($key);
}

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
sub st_get# (key)
{
    my ($self, $key) = @_;
    $self->_state;
    return $self->_get($key);
}

# Method: set
#
#      Set an arbitrary key
#
# Parameters:
#
#       key -
#
sub set # (key)
{
    my ($self, $key, $value) = @_;
    $self->_config;
    return $self->_set($key, $value);
}

# Method: set
#
#      Set an arbitrary key
#
# Parameters:
#
#       key -
#
sub st_set# (key)
{
    my ($self, $key, $value) = @_;
    $self->_state;
    return $self->_set($key, $value);
}

#############

sub _get # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    return $self->redis->get($key);
}

sub _set #
{
    my ($self, $key, $value) = @_;
    $key = $self->_key($key);
    $self->redis->set_string($key, $value);
}

#############

sub _unset # (key)
{
    my ($self, $key) = @_;
    $key = $self->_key($key);
    $self->_backup;
    $self->redis->unset($key);
}

#
# Method: unset
#
#       Unset a given key
#
# Parameters:
#
#       key -
#
#
sub unset # (key)
{
    my ($self, $key) = @_;
    $self->_config;
    $self->_unset($key);
}

sub st_unset # (key)
{
    my ($self, $key) = @_;
    $self->_state;
    $self->_unset($key);
}

#############

sub _set_list # (key, type, value)
{
    my ($self, $key, $type, $val) = @_;
    $key = $self->_key($key);
    $self->_backup;
    $self->redis->set_list($key, $val);
}

#
# Method: set_list
#
#       Sets a list of valueis. The type for the values is also specified
#
# Parameters:
#
#       key -
#       type - type for each value
#       values - (ref to an array) proper list of values
#
sub set_list # (key, type, value)
{
    my ($self, $key, $type, $val) = @_;
    $self->_config;
    $self->_set_list($key, $type, $val);
}

sub st_set_list # (key, type, value)
{
    my ($self, $key, $type, $val) = @_;
    $self->_state;
    $self->_set_list($key, $type, $val);
}

#############

sub _hash_from_dir # (key)
{
    my ($self, $dir) = @_;
    my $hash = {};
    my @keys = @{$self->_all_entries_base($dir)};
    foreach (@keys) {
        my $val = $self->_get("$dir/$_");
        $hash->{$_} = $val;
    }
    return $hash;
}

#
# Method: hash_from_dir
#
#       It returns a hash containing all the entries in the directory
#       referenced by the key
#
# Parameters:
#
#       key -
#
# Returns:
#
#       hash ref - it contains entries/values
sub hash_from_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_config;
    return $self->_hash_from_dir($dir);
}

sub st_hash_from_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_state;
    return $self->_hash_from_dir($dir);
}

#############

sub _array_from_dir # (key)
{
    my ($self, $dir) = @_;
    my @array = ();
    my @subs = @{$self->_all_dirs_base($dir)};
    foreach (@subs) {
        my $hash = $self->_hash_from_dir("$dir/$_");
        $hash->{'_dir'} = $_;
        push(@array, $hash);
    }
    return \@array;
}

#
# Method: array_from_dir
#
#       Given a key it returns an array using a hash reference to
#       contain in each element the directories under the key. Also, the
#       hash contains the key _dir which tells
#       you the directory's name
#
# Parameters:
#
#       key - the key to extract the array from
#
# Returns:
#
#       array ref - An array which contains entries/values. key '_dir' contains the directory's name
#
sub array_from_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_config;
    return $self->_array_from_dir($dir);
}

sub st_array_from_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_state;
    return $self->_array_from_dir($dir);
}

#############

sub _delete_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_backup;
    $dir = $self->_key($dir);
    $self->_delete_dir_internal($dir);
}

#
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
    $self->_delete_dir($dir);
}

sub st_delete_dir # (key)
{
    my ($self, $dir) = @_;
    $self->_state;
    $self->_delete_dir($dir);
}

#############

sub _delete_dir_internal # (key)
{
    my ($self, $dir) = @_;
    $self->redis->delete_dir($dir);
}

#
# Method: get_unique_id
#
#       It generates a unique random identifier with a leading
#       prefix in the root of the module's
#       namespace, if directory is passed, it will
#       be used instead the root directory.
#       Note that it does not create the entry, it
#       just returns a unique identifier, so it is up to you to create the
#       proper entry
#
# Parameters:
#
#       prefix  - prefix to be added to the root of the module's namespace
#       directory - directory to use instead root directory (optional)
#
# Returns:
#
#       string - unique identifier without directory path
sub get_unique_id # (prefix, directory?)
{
    my ($self, $prefix, $directory) = @_;
    return $self->_get_unique_id($prefix, $directory, 'dir_exists');
}

#
# Method: st_get_unique_id
#
#       It generates a unique random identifier with a leading
#       prefix in the root of the module's state
#       namespace, if directory is passed, it will
#       be used instead the root directory.
#       Note that it does not create the entry, it
#       just returns a unique identifier, so it is up to you to create the
#       proper entry
#
# Parameters:
#
#       prefix  - prefix to be added to the root of the module's state namespace
#       directory - directory to use instead root directory (optional)
#
# Returns:
#
#       string - unique identifier without directory path
sub st_get_unique_id # (prefix, directory?)
{
    my ($self, $prefix, $directory) = @_;
    return $self->_get_unique_id($prefix, $directory, 'st_dir_exists');
}


sub _get_unique_id
{
    my ($self, $prefix, $directory, $dirExistsMethod) = @_;

    if ($directory) {
        $directory .= '/';
    } else {
        $directory = "";
    }
    my $id = $prefix . int(rand(10000));
    while ($self->$dirExistsMethod($directory . $id)) {
        $id = $prefix . int(rand(10000));
    }
    return $id;
}


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
