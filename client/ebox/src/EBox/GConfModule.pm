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

package EBox::GConfModule;

use strict;
use warnings;

use base 'EBox::Module';

use Gnome2::GConf;
use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::GConfState;
use EBox::GConfConfig;

# Core modules
use File::Basename;
use File::Copy::Recursive;

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
	$self->{gconf} = Gnome2::GConf::Client->get_default;
	defined($self->{gconf}) or
		throw EBox::Exceptions::Internal("Error getting GConf client");
	$self->gconf->add_dir("/$ebox/modules/". $self->name, 'preload-none');
	$self->gconf->add_dir("/$ebox/state/". $self->name, 'preload-none');
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
     throw EBox::Exceptions::Internal($self->name . ' module already has changed state');


   $self->_dump_to_file();
}



# we override aroundRestoreconfig to save gconf data before dump module config
sub aroundRestoreConfig
{
  my ($self, $dir) = @_;
  $self->_load_from_file($dir);  
  $self->restoreConfig($dir);     
}


# load GConf entries from a file
sub _load_from_file # (dir?, key?) 
{
  my ($self, $dir, $key) = @_;
  ($dir) or $dir = EBox::Config::conf;

  $self->_config();

  my $file =  $self->_bak_file_from_dir($dir);
  -f $file or throw EBox::Exceptions::Internal("Backup file missing: ".
					       "$file.");
  ($key) or $key = $self->_key("");
  $self->_delete_dir_internal($key);
  `/usr/bin/gconftool --load=$file $key` and
    throw EBox::Exceptions::Internal("Error while restoring " .
				     "configuration from $file");
}


# we override aroundDumpConfig to save gconf data before dump module config
sub aroundDumpConfig
{
  my ($self, $dir) = @_;
  $self->_dump_to_file($dir);  
  $self->dumpConfig($dir);     
}

# dumps GConf entries to a file in the dir specified
sub _dump_to_file # (dir?) 
{
	my ($self, $dir) = @_;
	$self->_config();

	my $key = "/ebox/modules/" . $self->name;
	($dir) or $dir = EBox::Config::conf;
	my $file = $self->_bak_file_from_dir($dir);
	`/usr/bin/gconftool --dump $key > $file` and
		throw EBox::Exceptions::Internal("Error while backing up " .
						 "configuration on $file");
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
#   	Dismisses all changes done since the first write or delete operation.
#
sub revokeConfig
{
	my $self = shift;
	my $global = EBox::Global->getInstance();

	$global->modIsChanged($self->name) or return;
	$global->modRestarted($self->name);

	my $ro = $self->{ro};
	$self->{ro} = undef;
	$self->_load_from_file();
        # Restore <EBox::Types::File> which content a file
        $self->_restoreFilesFromBackup();
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
        # Backup a copy of the content of <EBox::Types::File>
        $self->_backupFiles();
	$self->_load_from_file(undef, "/ebox-ro/modules/". $self->name());
}

sub _backup
{
	my $self = shift;
	$self->_helper->backup();
}

#
# Method: gconf 
#
#   	Returns the current instance of gconf
#	
# Returns:
#
#	Gnome2::GConf object
#
sub gconf
{
	my $self = shift;
	return $self->{gconf};
}

sub _key # (key) 
{
	my ($self, $key) = @_;
	return $self->_helper->key($key);
}

#############

sub _gconf_wrapper # (method, @params?)
{
	my $self = shift;
	my $method = shift;
	my @parms  = @_;
	my $scalar;
	my @array;

	my $code = $self->gconf->can($method);
	unless ($code){
		throw EBox::Exceptions::Internal("method $method  doesnt exists"
						 . " in EBox::GConfModule\n");
	}

	my $ret = wantarray;
	eval { 
		if ($ret){
			@array = &$code($self->gconf, @parms);
		} else {
            {
                # Silent really weird warning which is likeley due to
                # the perl version
                no warnings;
			    $scalar = &$code($self->gconf, @parms);
            }
		}	
	};
	if ($@) {
		throw EBox::Exceptions::Internal("gconf error using function "
						 . "$method and params @parms"
						 . "\n $@");
	}

	return wantarray ? @array : $scalar;	
}


sub _dir_exists # (key) 
{
	my ($self, $key) = @_;
	$key = $self->_key($key);
	return $self->_gconf_wrapper("dir_exists", $key);
}

#
# Method: dir_exists 
#
#   	Given a key referencing a directory tells you if it exists
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
	my @array = $self->_all_entries($key);
	my @names = ();
	foreach (@array) {
		push(@names, basename($_));
	}
	return \@names;
}

#
# Method: all_entries_base 
#
#   	Given a key it returns all directories within, removing
#       any leading directory component.
#
# Parameters:
#
#	key
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

sub _all_dirs # (key) 
{
	my ($self, $key) = @_;
	$key = $self->_key($key);
	my @ret = $self->_gconf_wrapper("all_dirs", $key);
	unless (@ret) {
		@ret = ();
	}
	return @ret;
}

#
# Method: all_dirs 
#
#   	Given a key it returns all directories within.	
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
	return $self->_gconf_wrapper("all_entries", $key);
}

#
# Method: all_entries 
#
#   	Given a key it returns all entries within. Entries are all
#       those keys which are not directories, hence they contain a value
#
# Parameters:
#
#	key -
#
# Returns:
#
#       array of strings - Each string contains an entry
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
	$self->gconf->suggest_sync;
	return $self->_gconf_wrapper("get_bool", $key);
}

#
# Method: get_bool 
#
#	Returns the value of a boolean key.
#
# Parameters:
#
#	key -
#
# Returns:
#
#	boolean - key's value#
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
	$self->_gconf_wrapper("set_bool", $key, $val);
	$self->gconf->suggest_sync;
}

#
# Method: set_bool 
#
#	Sets a boolean key	
#
# Parameters:
#
#	key - key to set
#	value - value
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
	$self->gconf->suggest_sync;
	return $self->_gconf_wrapper("get_int", $key);
}

#
# Method: get_int
#
#	Returns the value of an integer key.
#
# Parameters:
#
#	key -
#
# Returns:
#
#	integer - key's value
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
	$self->_gconf_wrapper("set_int", $key, $val);
	$self->gconf->suggest_sync;
}

#
# Method: set_int
#
#	Sets an integer key	
#
# Parameters:
#
#	key - key to set
#	value - value
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
	$self->gconf->suggest_sync;
	return $self->_gconf_wrapper("get_string", $key);
}

#
# Method: get_string
#
#	Returns the value of an string key.
#
# Parameters:
#
#	key -
#
# Returns:
#
#	string - key's value
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
	$self->_gconf_wrapper("set_string", $key, $val);
	$self->gconf->suggest_sync;
}

#
# Method: set_string
#
#	Sets a string  key	
#
# Parameters:
#
#	key - key to set
#	value - value
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
	$self->gconf->suggest_sync;
	my $list = $self->_gconf_wrapper("get_list", $key);
	if ($list){
		return $list;
	} else {
		return [];
	}
}

#
# Method: get_list
#
#	Returns the value of an string key.
#
# Parameters:
#
#	key -
#
# Returns:
#	
#	It returns the list of values stored in the key .
#
#	ref to an array  - the list of values 
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

#############

sub _get # (key) 
{
	my ($self, $key) = @_;
	$key = $self->_key($key);
	$self->gconf->suggest_sync;
	return $self->_gconf_wrapper("get", $key);
}

#############

sub _unset # (key) 
{
	my ($self, $key) = @_;
	$key = $self->_key($key);
	$self->_backup;
	$self->_gconf_wrapper("unset", $key);
	$self->gconf->suggest_sync;
}

#
# Method: unset 
#
#	Unset a given key	
#
# Parameters:
#
#	key -
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
	$self->_gconf_wrapper("set_list", $key, $type, $val);
	$self->gconf->suggest_sync;
}

#
# Method: set_list 
#
#	Sets a list of valueis. The type for the values is also specified	
#
# Parameters:
#
#	key -
#	type - type for each value
#	values - (ref to an array) proper list of values
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
		$hash->{$_} = $val->{value};
	}
	return $hash;
}

#
# Method: hash_from_dir 
#
#	It returns a hash containing all the entries in the directory
#       referenced by the key
#
# Parameters:
#
#	key -
#
# Returns:
#
#	hash ref - it contains entries/values
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
#	Given a key it returns an array using a hash reference to
#       contain in each element the directories under the key. Also, the
#       hash contains the key _dir which tells
#       you the directory's name
#
# Parameters:
#
#	key - the key to extract the array from
#
# Returns:
#
#	array ref - An array which contains entries/values. key '_dir' contains the directory's name
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
#	Removes a whole directory
#
# Parameters:
#
#	key - directory to be removed
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
	my @keys = $self->_gconf_wrapper("all_entries", $dir);
	foreach (@keys) {
		$self->_gconf_wrapper("unset", $_);
	}
	@keys = $self->_gconf_wrapper("all_dirs", $dir);
	foreach (@keys) {
		$self->_delete_dir_internal($_);
	}
	$self->_gconf_wrapper("unset", $dir);
	$self->gconf->suggest_sync;
}

#
# Method: get_unique_id 
#
# 	It generates a unique random identifier with a leading
#       prefix in the root of the module's
#       namespace, if directory is passed, it will
#       be added to the path. Note that it does not create the entry, it
#       just returns a unique identifier, so it is up to you to create the
#       proper entry
#
# Parameters:
#
#       prefix  - prefix to be added to the root of the module's namespace
#	directory - if the directory is passed, this is added to the path
#
# Returns:
#
#	string - unique identifier
sub get_unique_id # (prefix, directory?)
{
	my ($self, $prefix, $directory) = @_;
	return $self->_get_unique_id($prefix, $directory, 'dir_exists');
}

#
# Method: st_get_unique_id 
#
# 	It generates a unique random identifier with a leading
#       prefix in the root of the module's state
#       namespace, if directory is passed, it will
#       be added to the path. Note that it does not create the entry, it
#       just returns a unique identifier, so it is up to you to create the
#       proper entry
#
# Parameters:
#
#       prefix  - prefix to be added to the root of the module's state namespace
#	directory - if the directory is passed, this is added to the path
#
# Returns:
#
#	string - unique identifier
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

# Method: _restoreFilesFromBackup
#
#     Restore the files stored using <EBox::Types::File> type by
#     models, therefore the model itself must be a
#     <EBox::Model::ModelProvider> instance
#
sub _restoreFilesFromBackup
{

    my ($self) = @_;

    my $filePaths = $self->_filePaths();
    if ( @{$filePaths} > 0 ) {
        foreach my $filePath (@{$filePaths}) {
            File::Copy::Recursive::fcopy($filePath . '.bak', $filePath)
                or throw EBox::Exceptions::Internal('Cannot copy from ' .
                                                    $filePath . ".bak to $filePath");
        }
    }
}

# Method: _backupFiles
#
#     Backup the files stored using <EBox::Types::File> type by
#     models, therefore the model itself must be a
#     <EBox::Model::ModelProvider> instance
#
sub _backupFiles
{

    my ($self) = @_;

    my $filePaths = $self->_filePaths();
    if ( @{$filePaths} > 0 ) {
        foreach my $filePath (@{$filePaths}) {
            File::Copy::Recursive::fcopy($filePath, $filePath  . '.bak')
                or throw EBox::Exceptions::Internal('Cannot copy from '
                                                    . "$filePath to $filePath"
                                                    . '.bak');
        }
    }
}


# Method to get those file full paths which are enclosed within this
# model provider
# Return value: array ref with the current file paths
sub _filePaths
{
    my ($self) = @_;

    unless ( $self->isa('EBox::Model::ModelProvider') ) {
        return ();
    }

    my @filePaths = ();
    my $models = $self->models();
    foreach my $model (@{$models}) {
        my $hasFileType = 0;
        foreach my $fieldName ( @{$model->fields()} ) {
            if ( $model->fieldHeader($fieldName)->isa('EBox::Types::File')) {
                $hasFileType = 1;
                last;
            }
        }
        if ( $hasFileType ) {
            foreach my $modelRow (@{$model->rows()}) {
                foreach my $field (@{$modelRow->{values}} ) {
                    if ( $field->isa('EBox::Types::File' )) {
                        push ( @filePaths, $field->path()) if ( $field->path() ne '');
                    }
                }
            }
        }
    }
    return \@filePaths;
}

1;
