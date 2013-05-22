# Copyright (C) 2008-2013 eBox Technologies S.L.
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
use strict;
use warnings;

package EBox::Module::Config;
use base 'EBox::Module::Base';

use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::File;
use EBox::Config::Redis;
use EBox::Model::Manager;

use File::Basename;
use Test::Deep::NoTest qw(eq_deeply);

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
    my $redis = delete $opts{redis};
    if ($redis) {
        $self->{redis} = EBox::Config::Redis->instance(customRedis => $redis);
    } else {
        $self->{redis} = EBox::Config::Redis->instance();
    }
    unless (defined($self->{redis})) {
        throw EBox::Exceptions::Internal("Error getting Redis client");
    }

    return $self;
}

sub model
{
    my ($self, $name) = @_;

    EBox::Model::Manager->instance()->_component('model', $self, $name);
}

sub composite
{
    my ($self, $name) = @_;

    EBox::Model::Manager->instance()->_component('composite', $self, $name);
}

# Method: models
#
#      Get the models from the model manager
#
# Returns:
#
#      Array ref - containing the model instances for this module
#
sub models
{
    my ($self) = @_;

    EBox::Model::Manager->instance()->models($self);
}

# Method: composites
#
#      Get the composites from the model manager
#
# Returns:
#
#      Array ref - containing the composite instances for this module
#
sub composites
{
    my ($self) = @_;

    EBox::Model::Manager->instance()->composites($self);
}

# we override aroundRestoreconfig to restore conf data before restoring config
sub aroundRestoreConfig
{
    my ($self, $dir, @extraOptions) = @_;

    $self->_load_from_file($dir);

    $self->restoreFilesFromArchive($dir);

    $self->restoreConfig($dir, @extraOptions);
}

sub _state_bak_file_from_dir
{
    my ($self, $dir) = @_;
    $dir =~ s{/+$}{};
    my $file = "$dir/" . $self->name . ".state";
    return $file;
}

# load config entries from a file
sub _load_from_file
{
    my ($self, $dir, $dst) = @_;
    ($dir) or $dir = EBox::Config::conf;
    my $file = $self->_bak_file_from_dir($dir);
    my $src =  $self->name() . '/conf';

    if (not $dst) {
        $dst = $self->_key('');
    }

    $self->_load_redis_from_file($file, $src, $dst);
}

sub _load_state_from_file
{
    my ($self, $dir, $dst) = @_;
    ($dir) or $dir = EBox::Config::conf;
    my $file = $self->_state_bak_file_from_dir($dir);
    my  $src =  $self->_st_key('');
    if (not $dst) {
        $dst = $self->_st_key('');
    }
    $self->_load_redis_from_file($file, $src, $dst);
}

sub _load_redis_from_file
{
   my ($self, $file, $src, $dst) = @_;
    if (not -f $file)  {
        EBox::error("Backup file '$file' missing for module " . $self->name);
        return;
    } elsif (not -r $file) {
        EBox::error("Cannot read backup file '$file' for module " . $self->name);
    }

    # Import to tmp dir and convert paths to $dst dest
    $self->{redis}->import_dir_from_file($file, 'tmp');
    $self->{redis}->backup_dir('tmp/' . $src, $dst);
    $self->{redis}->delete_dir('tmp');
}

sub aroundDumpConfig
{
    my ($self, $dir, @options) = @_;

    $self->_dump_to_file($dir);
    # dump also state, it will not be restored as default
    $self->_dump_state_to_file($dir);

    $self->backupFilesInArchive($dir);

    $self->dumpConfig($dir, @options);
}

# dumps GConf entries to a file in the dir specified
sub _dump_to_file
{
    my ($self, $dir) = @_;
    ($dir) or $dir = EBox::Config::conf;

    my $key = $self->name() . '/conf';
    my $file = $self->_bak_file_from_dir($dir);
    $self->{redis}->export_dir_to_file($key, $file);
}

sub _dump_state_to_file
{
     my ($self, $dir) =  @_;
     ($dir) or $dir = EBox::Config::conf;

     my $key = $self->_st_key();
     my $file = $self->_state_bak_file_from_dir($dir);
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

    $self->modelsRevokeConfig();

# Disabled until method si reimplemented
#    $self->_revokeConfigFiles();

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

    $self->modelsSaveConfig();

    $self->_copy_to_ro();

# Disabled until method si reimplemented
#    $self->_saveConfigFiles();
}

sub _copy_to_ro
{
    my ($self) = @_;

    $self->_copy('conf', 'ro');
}

sub _copy_from_ro
{
    my ($self) = @_;

    $self->_copy('ro', 'conf');
}

sub _copy
{
    my ($self, $src, $dst) = @_;

    my $name = $self->name();
    $self->{redis}->backup_dir("$name/$src", "$name/$dst");
}

# TODO: remove all the low-level _change calls here if at some point everything is modelized
sub _change
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance($self->{ro});
    $global->modChange($self->name);
}

sub _key
{
    my ($self, $key) = @_;

    my $dir = $self->{ro} ? 'ro' : 'conf';

    my $ret = $self->{name} . "/$dir";
    if ($key) {
        $ret .= "/$key";
    }

    return $ret;
}

sub _st_key
{
    my ($self) = @_;

    return $self->{name} . '/state';
}

sub _ro_key
{
    my ($self, $key) = @_;

    return $self->{name} . "/ro/$key";
}

#############

sub get_state
{
    my ($self) = @_;

    $self->{redis}->get($self->_st_key(), {});
}

sub set_state
{
    my ($self, $hash) = @_;

    $self->{redis}->set($self->_st_key(), $hash);
}

sub st_entry_exists
{
    my ($self, $key) = @_;

    my $state = $self->get_state();
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

    return $self->get($key, 0);
}

sub st_get_bool
{
    my ($self, $key) = @_;

    return $self->st_get($key, 0);
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

    $self->set($key, $val ? 1 : 0);
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

    return $self->get($key);
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

    $self->set($key, $val);
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

    return $self->get($key);
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

    $self->set($key, $val);
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

    return $self->get($key, []);
}

sub st_get_list
{
    my ($self, $key) = @_;

    return $self->st_get($key, []);
}

#############

sub set_hash
{
    my ($self, $key, $value) = @_;

    $key = $self->_key($key);
    $self->redis->set($key, $value);
}

sub get_hash
{
    my ($self, $key) = @_;

    return $self->get($key, {});
}

#############

# Method: get
#
#       Returns the value of a key
#
# Parameters:
#
#       key - string with the key
#       value - default value to be returned if the key does not exist
#
# Returns:
#
#   value of the key or defaultValue if specified and key does not exist
#
sub get
{
    my ($self, $key, $defaultValue) = @_;

    $key = $self->_key($key);
    return $self->redis->get($key, $defaultValue);
}

sub st_get
{
    my ($self, $key, $defaultValue) = @_;

    my $state = $self->get_state();
    if (not exists $state->{$key}) {
        return $defaultValue;
    }
    return $state->{$key};
}

# Method: set
#
#      Set an arbitrary key and mark the module as changed if not readonly
#
# Parameters:
#
#       key - string with the key
#       value - scalar or ref with the value
#
sub set
{
    my ($self, $key, $value) = @_;

    $self->_set($key, $value);

    # Only mark as changed if stored value in ro is different
    unless ($self->{ro}) {
        my $oldvalue = $self->{redis}->get($self->_ro_key($key));
        unless (eq_deeply($value, $oldvalue)) {
            $self->_change();
        }
    }
}

# Method: _set
#
#      Set an arbitrary key without marking the module as changed
#
# Parameters:
#
#       key - string with the key
#       value - scalar or ref with the value
#
sub _set
{
    my ($self, $key, $value) = @_;

    $self->{redis}->set($self->_key($key), $value);
}

sub st_set
{
    my ($self, $key, $value) = @_;

    my $state = $self->get_state();
    $state->{$key} = $value;
    $self->set_state($state);
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

    $key = $self->_key($key);
    $self->redis->unset($key);
    $self->_change() unless $self->{ro};
}

sub st_unset
{
    my ($self, $key) = @_;

    my $state = $self->get_state();
    delete $state->{$key};
    $self->set_state($state);
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
    $self->set($key, $val);
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

    $dir = $self->_key($dir);
    $self->redis->delete_dir($dir);
    $self->_change() unless $self->{ro};
}

#############

# files stuff we have to put this stuff in confmodule bz if we put into models
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

# FIXME: reimplement this
#sub _fileList
#{
#    my ($self, $dir) = @_;
#
#
#    if (not $self->dir_exists($dir)) {
#         return [];
#    }
#
#    my @files  = map {
#        $self->get_string($_);
#    } @{$self->all_entries($dir)};
#
#    return \@files;
#}

#sub _saveConfigFiles
#{
#    my ($self) = @_;
#    my $dir = $self->_filesToRemoveIfCommittedDir();
#    $self->_removeFilesFromList($dir);
#}


# FIXME: reimplement this
#sub _clearFilesToRemoveLists
#{
#    my ($self) = @_;
#
#    return;
#
#    my @dirs = @{ $self->_fileListDirs() };
#
#    foreach my $dir (@dirs) {
#        if ($self->dir_exists($dir)) {
#            $self->delete_dir($dir);
#        }
#    }
#}

#sub _revokeConfigFiles
#{
#    my ($self) = @_;
#
#    my $dir = $self->_filesToRemoveIfRevokedDir();
#    $self->_removeFilesFromList($dir);
#}

#sub _removeFilesFromList
#{
#    my ($self, $dir) = @_;
#
#    my @files = @{ $self->_fileList($dir) };
#    foreach my $file ( @files  ) {
#        my $backupPath         = EBox::Types::File->backupPath($file);
#        my $noPreviousFilePath = EBox::Types::File->noPreviousFilePath($file);
#
#        EBox::Sudo::root("rm -rf '$file' '$backupPath' '$noPreviousFilePath'");
#    }
#
#    $self->_clearFilesToRemoveLists();
#}

# Method: modelsSaveConfig
#
#    Method called when the conifguraiton of a modules is saved
sub modelsSaveConfig
{
    my ($self) = @_;

#    $self->modelsBackupFiles();
}

# Method: modelsRevokeConfig
#
#    Method called when the conifguraiton of a modules is revoked
sub modelsRevokeConfig
{
    my ($self) = @_;

#    $self->modelsRestoreFiles();
}

# Method: backupFiles
#
#   Make an actual configuration backup of all the files contained in the
#   models
sub modelsBackupFiles
{
    my ($self) = @_;

#    foreach my $model ( @{ $self->models() } ) {
#        if ($model->can('backupFiles')) {
#            $model->backupFiles();
#        }
#    }
}

# Method: restoreFiles
#
#  Restores the actual configuration backup of files in the models , thus
#  discarding the lasts changes in files
sub modelsRestoreFiles
{
    my ($self) = @_;

#    foreach my $model ( @{ $self->models() } ) {
#        if ($model->can('restoreFiles')) {
#            $model->restoreFiles();
#        }
#    }
}

sub _filesArchive
{
    my ($self, $dir) = @_;
    return "$dir/modelsFiles.tar";
}

# Method: backupFilesInArchive
#
#  Backup all the modules' files in a compressed archive in the given dir
#  This is used to create backups
#
#   Parameters:
#   dir - directory where the archive will be stored
sub backupFilesInArchive
{
    my ($self, $dir) = @_;

    my @filesToBackup;
    foreach my $model ( @{ $self->models() } ) {
        if ($model->can('filesPaths')) {
            push @filesToBackup, @{ $model->filesPaths() };
        }
    }

    @filesToBackup or
        return;

    my $archive = $self->_filesArchive($dir);


    my $firstFile  = shift @filesToBackup;
    my $archiveCmd = "tar  -C / -cf $archive --atime-preserve --absolute-names --preserve-permissions --preserve-order --same-owner '$firstFile'";
    EBox::Sudo::root($archiveCmd);

    # we append the files one per one bz we don't want to overflow the command
    # line limit. Another approach would be to use a file catalog however I think
    # that for only a few files (typical situation for now) the append method is better
    foreach my $file (@filesToBackup) {
        $archiveCmd = "tar -C /  -rf $archive --atime-preserve --absolute-names --preserve-permissions --preserve-order --same-owner '$file'";
        EBox::Sudo::root($archiveCmd);
    }
}

# Method: restoreFilesFromArchive
#
#  Restore all the module's file from the compressed archive in the given dir
#  This is used to restore backups
#
#   Parameters:
#   dir - directory where the archive is stored
sub restoreFilesFromArchive
{
    my ($self, $dir) = @_;
    my $archive = $self->_filesArchive($dir);

    (-f $archive) or return;

    my $restoreCmd = "tar  -C / -xf $archive --atime-preserve --absolute-names --preserve-permissions --preserve-order --same-owner";
    EBox::Sudo::root($restoreCmd);
}

# Method: global
#
#  Gets an EBox::Global instance with the same read-only status as the module
#
sub global
{
    my ($self) = @_;
    return EBox::Global->getInstance($self->{ro});
}

1;
