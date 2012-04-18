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

package EBox::Module::Config;

use strict;
use warnings;

use base 'EBox::Module::Base';

use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Module::Config::State;
use EBox::Module::Config::Conf;
use EBox::Types::File;
use EBox::Config::Redis;
use EBox::Model::Manager;

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
    $self->{state} = new EBox::Module::Config::State($self, $self->{ro});
    $self->{config} = new EBox::Module::Config::Conf($self, $self->{ro});
    $self->{helper} = $self->{config};

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

sub models
{
    my ($self) = @_;

    EBox::Model::Manager->instance()->models($self);
}

sub composites
{
    my ($self) = @_;

    EBox::Model::Manager->instance()->composites($self);
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

# we override aroundRestoreconfig to save conf data before dump module config
sub aroundRestoreConfig
{
  my ($self, $dir, @extraOptions) = @_;

  $self->_load_from_file($dir);

  $self->restoreFilesFromArchive($dir);

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

  $self->backupFilesInArchive($dir);

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

    $self->modelsRevokeConfig();

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

    $self->modelsSaveConfig();

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

# Method: _exposedMethods
#
#      Get the list of exposed method to manage the models. It could
#      be very useful for Perl scripts on local or using SOAP protocol
#
# Returns:
#
#      hash ref - the list of the exposes method in a hash ref every
#      component which has the following description:
#
#      methodName => { action   => '[add|set|get|del]',
#                      path     => [ 'modelName', 'submodelFieldName1', 'submodelFieldName2',... ],
#                      indexes  => [ 'indexFieldNameModel', 'indexFieldNameSubmodel1' ],
#                      [ selector => [ 'field1', 'field2'...] ] # Only available for set/get actions
#
#      The 'indexes' must be unique (at least the field 'id' is unique
#      and 'position' as well) and the submodel field name refers to the
#      name of the <EBox::Types::HasMany> field on the previous model
#      in the list.
#
#      If the model template may have more than one instance, the
#      model index must be passed as the first parameter to
#      distinguish from the remainder model instances.
#
#      If the action is 'set' and the selector is just one field you
#      can omit the field name when setting the element as the
#      following example shows:
#
#      $modelProvider->setAttr($attrValue);
#      $modelProvider->setAttr( attr => $attrValue);
#
#      The method call will follow this pattern:
#
#      methodName( ['modelIndex',] '/index1/index2/index3...', ...) if there are more
#      than one index
#
#      methodName( ['modelIndex',] 'index1', ...) if there are just one argument
#
#
sub _exposedMethods
{
    return {};
}

sub DESTROY { ; }

# Method: AUTOLOAD
#
#       It does a mapping among the exposed methods and the autoload
#       methods created at the DataTable class
#
# Parameters:
#
#       params - array the parameters from the undefined method
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown if the method is not
#       exposed
#
sub AUTOLOAD
{
    my ($self, @params) = @_;

    my $methodName = our $AUTOLOAD;

    $methodName =~ s/.*:://;

    if (UNIVERSAL::can($self, '_exposedMethods')) {
        my $exposedMethods = $self->_exposedMethods();
        if ( exists $exposedMethods->{$methodName} ) {
            return $self->_callExposedMethod($exposedMethods->{$methodName}, \@params);
        } else {
            use Devel::StackTrace;
            my $trace = new Devel::StackTrace();
            EBox::debug($trace->as_string());

            throw EBox::Exceptions::Internal("Undefined method $methodName");
        }
    } else {
        use Devel::StackTrace;
        my $trace = new Devel::StackTrace();
        EBox::debug($trace->as_string());

        throw EBox::Exceptions::Internal("Undefined method $methodName");
    }
}

# Method: _callExposedMethod
#
#     This method does the mapping between the exposed method and the
#     autoload method parsed by the DataTable class
#
# Parameters:
#
#     methodDescription - hash ref the method description as it is
#     explained by <EBox::Model::ModelProvider::_exposedMethods>
#     header
#
#     params - array ref the parameters from the undefined method
#
sub _callExposedMethod
{
    my ($self, $methodDesc, $paramsRef) = @_;

    my @path = @{$methodDesc->{path}};
    my @indexes = @{$methodDesc->{indexes}} if exists ($methodDesc->{indexes});
    my $action = $methodDesc->{action};
    my @selectors = @{$methodDesc->{selector}} if exists ($methodDesc->{selector});

    # Getting the model instance
    my $model = EBox::Model::Manager->instance()->model($path[0]);
    if (ref ($model) eq 'ARRAY') {
        # Search for the chosen model
        my $index = shift (@{$paramsRef});
        foreach my $modelInstance (@{$model}) {
            if ( $modelInstance->index() eq $index ) {
                $model = $modelInstance;
                last;
            }
        }
    } elsif ($model->index()) {
        shift(@{$paramsRef});
    }
    unless (defined ($model) or (ref ($model) eq 'ARRAY')) {
        throw EBox::Exceptions::Internal("Cannot retrieve model $path[0] "
                . 'it may be a multiple one or it '
                . 'is passed a wrong index');
    }

    # Set the indexField for every model with index
    if (@indexes > 0) {
        unless ($indexes[0] eq 'id' or
                $indexes[0] eq 'position') {
            $model->setIndexField($indexes[0]);
        }
        my $submodel = $model;
        foreach my $idx (1 .. $#indexes) {
            my $hasManyField = $submodel->fieldHeader($path[$idx]);
            my $submodelName = $hasManyField->foreignModel();
            $submodel = EBox::Model::Manager->instance()->model($submodelName);
            unless ( $indexes[$idx] eq 'id' or
                    $indexes[$idx] eq 'position') {
                $submodel->setIndexField($indexes[$idx]);
            }
        }
    }

    # Submodel in the method name
    my $subModelsName = "";
    # Remove the model name
    shift (@path);
    foreach my $field (reverse @path) {
        $subModelsName .= ucfirst ( $field ) . 'To';
    }

    # The name
    my $mappedMethodName;
    if ($subModelsName) {
        $mappedMethodName = $action . $subModelsName . $model->name();
    } else {
        $mappedMethodName = $action;
    }

    # The parameters
    my @indexValues = ();
    unless (ref ($paramsRef->[0])) {
        if (defined ($paramsRef->[0])) {
            my $separator;
            if (exists $methodDesc->{'separator'}) {
                $separator = $methodDesc->{'separator'};
            } else {
                $separator = '/';
            }
            @indexValues = grep { $_ ne '' } split ($separator,
                    $paramsRef->[0],
                    scalar(@indexes) + 1);
            # Remove the index param if any
            shift (@{$paramsRef});
        }
    }
    my @mappedMethodParams = @indexValues;
    if (@selectors == 1 and $action eq 'set') {
        # If it is a set action and just one selector is supplied,
        # the field name is set as parameter
        push (@mappedMethodParams, $selectors[0]);
    }
    push (@mappedMethodParams, @{$paramsRef});
    if (@selectors > 0 and $action eq 'get') {
        my $selectorsRef = \@selectors;
        push (@mappedMethodParams, $selectorsRef);
    }

    return $model->$mappedMethodName(@mappedMethodParams);
}

# Method: modelsSaveConfig
#
#    Method called when the conifguraiton of a modules is saved
sub modelsSaveConfig
{
    my ($self) = @_;

    $self->modelsBackupFiles();
}

# Method: modelsRevokeConfig
#
#    Method called when the conifguraiton of a modules is revoked
sub modelsRevokeConfig
{
    my ($self) = @_;

    $self->modelsRestoreFiles();
}

# Method: backupFiles
#
#   Make an actual configuration backup of all the files contained in the
#   models
sub modelsBackupFiles
{
    my ($self) = @_;

    foreach my $model ( @{ $self->models() } ) {
        if ($model->can('backupFiles')) {
            $model->backupFiles();
        }
    }
}

# Method: restoreFiles
#
#  Restores the actual configuration backup of files in the models , thus
#  discarding the lasts changes in files
sub modelsRestoreFiles
{
    my ($self) = @_;

    foreach my $model ( @{ $self->models() } ) {
        if ($model->can('restoreFiles')) {
            $model->restoreFiles();
        }
    }
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
    my $archiveCmd = "tar  -C / -cf $archive --atime-preserve --absolute-names --preserve --same-owner $firstFile";
    EBox::Sudo::root($archiveCmd);

    # we append the files one per one bz we don't want to overflow the command
    # line limit. Another approach would be to use a file catalog however I think
    # that for only a few files (typical situation for now) the append method is better
    foreach my $file (@filesToBackup) {
        $archiveCmd = "tar -C /  -rf $archive --atime-preserve --absolute-names --preserve --same-owner $file";
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

    my $restoreCmd = "tar  -C / -xf $archive --atime-preserve --absolute-names --preserve --same-owner";
    EBox::Sudo::root($restoreCmd);
}

1;
