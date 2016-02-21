# Copyright (C) 2008-2013 Zentyal S.L.
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
use TryCatch;

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
    $self->_change() unless $self->{ro};
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

sub _filesArchive
{
    my ($self, $dir) = @_;
    return "$dir/moduleFiles.tar";
}


# Method: replicationExcludeKeys
#
#  Returns the list of keys that need to be excluded from HA conf replication
#
sub replicationExcludeKeys
{
    return [];
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


sub searchContents
{
    my ($self, $searchStringRe) = @_;
    my ($modelMatches) = $self->_searchRedisConfKeys($searchStringRe);
    return $modelMatches;
}

sub _allValuesFromKey
{
    my ($self, $value) = @_;
    my $refType = ref $value;
    my @allKeyValues;
    if ($refType eq 'ARRAY') {
        @allKeyValues = @{ $value };
    } elsif ($refType eq 'HASH') {
        @allKeyValues = values %{ $value };
    } else {
        if ($value) {
            @allKeyValues = ($value);
        }
    }

    @allKeyValues = map {
        (ref $_) ? @{ $self->_allValuesFromKey($_) } : ($_)
    } @allKeyValues;

    return \@allKeyValues;
}

sub _searchRedisConfKeys
{
    my ($self, $searchStringRe) = @_;
    my %modelMatches;
    my %noModelMatches;

    my $redis = $self->redis();
    my @keys = $redis->_keys($self->_key('*'));
    if (not @keys) {
        return [];
    }
    foreach my $key (@keys) {
        if ($key =~ m{/order$}) {
            next;
        } elsif ($key =~ m{/max_id$}) {
            next;
        }
        my $value = $redis->get($key);
        my @allKeyValues = @{ $self->_allValuesFromKey($value) };

        my $valueMatch = 0;
        foreach my $keyVal (@allKeyValues) {
            if ($keyVal =~ m/$searchStringRe/) {
                $valueMatch = 1;
                last;
            }
        }
        if (not $valueMatch) {
            next;
        }

        my $modelMatch = $self->_keyToModelMatch($key, $searchStringRe);
        if ($modelMatch ) {
            if ($modelMatch->{hidden}) {
                next;
            }
            # TODO: use composites?
            my $modelMatchUrl = '/' . $modelMatch->{module} . '/View/' . $modelMatch->{model};
            if ($modelMatch->{dir}) {
                $modelMatchUrl .= '?directory=' . $modelMatch->{dir};
            }
            if (not exists $modelMatches{$modelMatchUrl}) {
                $modelMatch->{url} = $modelMatchUrl;
                $modelMatch->{linkElements}->[-1]->{link} = $modelMatchUrl;
                $modelMatches{$modelMatchUrl} = $modelMatch;

            } else {
                # not sure what to do about more matches for the same model,
                # ignoring them for now
            }
        } else {
            $noModelMatches{$key} = 1;
        }
    }


    return ([values %modelMatches], [keys %noModelMatches]);
}

# this only for models, for custom redis this must be overridden
sub _keyToModelMatch
{
    my ($self, $key, $searchStringRe) = @_;
    my ($modName, $dir) = split '/conf/', $key, 2;
    if ((not $modName) or (not $dir) ) {
        EBox::error("Unexpected key format: '$key'");
        return undef;
    } elsif ($self->name ne $modName) {
        EBox::error("Bad match mod name $modName <-> $key");
        return undef;
    }

    my @parts = split '/keys/', $dir;
    my $model = shift @parts;
    my $rowId = pop @parts;
    if (not $model or not $rowId) {
        # It may be a no-model key
        return undef;
    }

    my $global   = $self->global();
    my $modelModName = $modName;
    my $modelDir     = '';
    foreach my $part (@parts) {
        my ($id, $fieldName, $remaining) = split '/', $part;
        if ((not $id) or (not $fieldName) or $remaining) {
            EBox::error("Unexpected submodel part '$part' from key '$key'");
            return undef;
        }
        my $modelInstance = $global->modInstance($modelModName)->model($model);
        if ($modelDir) {
            $modelInstance->setDirectory($modelDir);
        } else {
            # init modelDir with the name of the first model
            $modelDir = $model;
        }
        my $field = $modelInstance->fieldHeader($fieldName);
        my $nextModel = $field->foreignModel();
        my @nextModelParts = split '/', $field->foreignModel();
        if (@nextModelParts == 1) {
            $model = $nextModelParts[0];
        } elsif (@nextModelParts == 2) {
            ($modelModName, $model) = @nextModelParts;
        } else {
            EBox::error("Unexpected foreingModel '" . $field->foreingModel() . "' from key '$key'");
            return undef;
        }

        # increase modelDir
        $modelDir .= '/keys/' . $part;
    }

    # get printable name with breadcrumbs
    my $modelInstance = $global->modInstance($modelModName)->model($model);
    if ($modelDir) {
        $modelInstance->setDirectory($modelDir);
    }

    if ($self->_modelMatchIsHidden($modelInstance, $key, $searchStringRe)) {
        return { hidden => 1 };
    }

    my $linkElements;
    if (@parts == 0) {
        $linkElements = [
             {  title => $self->model($model)->printableModelName()    }
         ];
    } else {
        $linkElements = $modelInstance->viewCustomizer()->HTMLTitle();
    }
    # add module name
    unshift @{$linkElements}, {  title => $global->modInstance($modName)->printableName()  };

    return {
        linkElements => $linkElements,
        module => $modName,
        model => $model,
        dir => $modelDir,
        rowId => $rowId,
       };
}

sub _modelMatchIsHidden
{
    my ($self, $modelInstance, $key, $searchStringRe) = @_;
    my $value = $self->redis->get($key);
    if ((ref $value) ne 'HASH') {
        EBox::error("Cannot find hash ref for modelMatch for key $key");
        return 0;
    }
    my $fieldName;
    while (my ($key, $keyValue) = each %{$value}) {
        if ($keyValue =~ m/$searchStringRe/) {
            $fieldName = $key;
            last;
        }
    }
    if (not $fieldName) {
        EBox::error("Cannot find field for modelMatch for key $key");
        return 0;
    }

    my $field;
    try {
        $field = $modelInstance->fieldHeader($fieldName);
    } catch ($ex) {
        try {
            my $realField;
            # maybe was a union type?.  Change fieldname and look for selected field
            # Assumption: no more than one level depth of union
            $fieldName =~ s{_.*$}{};
            # look for selected value
            foreach my $key (keys %{ $value }) {
                my $keyValue = $value->{$key};
                if ($keyValue eq $fieldName) {
                    if ($key =~ m/^(.*?)_selected$/) {
                        $realField = $1;
                        last;
                    }
                }
            }
            if (not $realField) {
                $realField = $fieldName;
            }

            $field = $modelInstance->fieldHeader($realField);
        } catch ($ex) {
            EBox::warn("When looking for field $fieldName in model " .
                           $modelInstance->name() . ': ' . $ex
                          );
       }
    }

    if (not $field) {
        # forbid, for be in the safe side
        return 1;
    }
    if ($field->isa('EBox::Types::Password')) {
        return 1;
    }

    return $field->hidden();
}

1;
