# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::ServiceManager
#
#   This class is responsible to check if a given module is going to
#   modify a file which has previously been modifyed by a user.
#
#   It uses MD5 digests to track the changes
#
#
package EBox::ServiceManager;

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use EBox::Global;
use EBox::Sudo qw(:all);

use Error qw(:try);
use File::Basename;

use constant GCONF_DIR => 'ServiceModule/';
use constant CLASS => 'EBox::Module::Service';
use constant OVERRIDE_USER_MODIFICATIONS_KEY => 'override_user_modification';

# Group: Public methods

sub new
{
    my $class = shift;

    my $ebox = EBox::Global->getInstance();

    my $self =
    {
        'gconfmodule' => $ebox,
    };

    bless($self, $class);

    return $self;
}

# Method: moduleStatus
#
#   It returns the status for all modules which implement the interface CLASS
#
#   The status is a hash ref containing:
#
#       configured - boolean to store if the user has accepted to carry out
#                    the operation that involve enabling the module
#       depends    - boolean to store if the module's dependencies are met
#                    and therefore it can be enabled or not
#       status     - boolean to store if the user wants the service enabled
#
# Returns:
#
#   Array ref of hashes containing the module's name and its status
#
sub moduleStatus
{
    my ($self) = @_;

    my $global = $self->{'gconfmodule'};

    my @mods;
    my $change = undef;
    #for my $mod (@{$global->modInstancesOfType(CLASS)}) {
    for my $modName (@{$self->_dependencyTree()}) {
        my $mod = $global->modInstance($modName);
        my $status = {};
        $status->{'configured'} = $mod->configured();
        $status->{'depends'} = $self->dependencyEnabled($mod->name());
        $status->{'status'} = $mod->isEnabled();
        $status->{'name'} = $mod->name();
        $status->{'printableName'} = $mod->printableName();
        $status->{'printableDepends'} = $self->printableDepends($mod->name());
        unless ($status->{'configured'} and $status->{'depends'}) {
            $status->{'status'} = undef;
            $mod->enableService(undef);
        }
        if ( $mod->showModuleStatus() ) {
            push (@mods, $status);
        }
    }

    return \@mods;
}

# Method: printableDepends 
#
#   Return the printable dependencies for a given module, that is: i18ized
#  
# Parameters:
#
#   module - module's name
#
# Returns:
#
#   Array ref
sub printableDepends 
{
    my ($self, $module) = @_;

    my $global = $self->{'gconfmodule'};

    my @depends;
    for my $mod (@{$global->modInstance($module)->enableModDepends()}) {
        push (@depends, $global->modInstance($mod)->printableName());
    }
    return \@depends;
}

# Method: dependencyEnabled
#
#   Check if every module's dependency is enabled
#
# Returns:
#
#   boolean - true if all dependencies are enabled
sub dependencyEnabled
{
    my ($self, $module) = @_;

    my $global = $self->{'gconfmodule'};

    for my $mod (@{$global->modInstance($module)->enableModDepends()}) {
        my $instance = $global->modInstance($mod);
        unless (defined($instance)) {
            EBox::debug("$mod can't be instanced");
            next;
        }

        next unless ($instance->isa(CLASS));
        
        return undef unless ($instance->isEnabled());
    }

    return 1;
}

# Method: enableServices
#
#   Enable/disable module services
#
# Parameters:
#
#   Hash containing the services and its required status
#
#   Example:
#
#   { 'network' => 1, 'samba' => undef }
sub enableServices
{
    my ($self, $services) = @_;


    my $global = $self->{'gconfmodule'};

    for my $mod (keys %{$services}) {
        my $instance = $global->modInstance($mod);
        unless (defined($instance)) {
            EBox::debug("$mod can't be instanced");
            next;
        }

        next unless ($instance->isa(CLASS));
        $instance->enableService($services->{$mod});
    }
}

# Method: checkFiles
#
#   This method must be called to get all those files which are going
#   to be modified by  eBox and have been modified by the user.
#
#   If <checkUserModifications> returns false, then this method will
#   return an empty array reference.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       key - file's path
#       value - some info about why you need to modify the file
#
#   Only those files which have been modified by the user are returned
sub checkFiles
{
    my ($self) = @_;

    unless ( $self->checkUserModifications() ) {
        return [];
    }

    my $global = EBox::Global->getInstance();
    my @mods;
    for my $modName (@{$global->modifiedModules()}) {
        my $modIns = $global->modInstance($modName);
        push (@mods, $modIns) if ($modIns->isa(CLASS));
    }

    my @modified;
    for my $mod (@mods) {
        next unless ($mod->configured());
        for my $file (@{$mod->usedFiles()}) { 
            $file->{'id'} = $self->_fileId($file);
            $file->{'globalId'} = $file->{'module'} . '_' . $file->{'id'};
            my $mod = $file->{'module'};
            my $path = $file->{'file'};
            if  ($self->_fileModified($file) 
                 or (not $self->modificationAllowed($mod, $path))) {
                push (@modified, $file);
            }
        }
    }

    return \@modified;
}

# Method: setAcceptedFiles
#
#   This method must be called to set those files which are allowed to
#   be modified.
#
#
# Params:
#
#   array ref - containing the global identifiers of the files
#
sub setAcceptedFiles 
{
    my ($self, $accept, $reject) = @_;

    my  $gconf = $self->{'gconfmodule'};

    my $regexp = '(.*)_([^_]+)$';
    for my $global (@{$accept}) {
        my ($module, $file) = $global =~ m/$regexp/;
        $gconf->st_set_bool(GCONF_DIR . "$module/$file/accepted", 1);
        $self->updateFileDigest($module, $self->_idToPath($module, $file));
    }

    for my $global (@{$reject}) {
        my ($module, $file) = $global =~ m/$regexp/;
        $gconf->st_set_bool(GCONF_DIR . "$module/$file/accepted", undef);
        $gconf->st_set_string(GCONF_DIR . "$module/$file/digest", "");
    }

}

# Method:  modificationAllowed
#
#    Given a file it returns the user policy for that file
#
# Params:
#
#   module - module's name
#   file - file's path
#
# Return:
#
#   boolean - true if the user allows the modification, false otherwise.
#             False indicates that either the user has rejected the modification
#             or has not established any policy yet
# 
sub modificationAllowed 
{
    my ($self, $module, $file) = @_;
    
    my $gconf = $self->{'gconfmodule'};

    my $fileEntry = {'module' => $module, 'file' => $file};
    my $fileId = $self->_fileId($fileEntry);

    return $gconf->st_get_bool(GCONF_DIR . "$module/$fileId/accepted");
}

# Method: skipModification
#
#   This method is used to check if a file can be modified or not.
#   It won't allow the modification if:
#
#       - The user has rejected to modify the file
#       - The user has accepted by there's been a manual change in the
#         file since the last time eBox modified it
#
# Parameters:
#
#   module - module's name
#   file   - file's path
#
# Return:
#
#   boolean - true if we must skip the modification, false otherwise
# 
sub skipModification 
{
    my ($self, $module, $file) = @_;

    return 0 unless ($self->checkUserModifications());
 
    my $gconf = $self->{'gconfmodule'};

    return 1 unless ($self->modificationAllowed($module, $file));

    my $fileEntry = {'module' => $module, 'file' => $file};
    my $fileId = $self->_fileId($fileEntry);
    $fileEntry->{'id'} = $fileId;


    return $self->_fileModified($fileEntry);
}

# Method: updateFileDigest 
#
#   This method is used to update a file digests. It should be used as soon
#   as eBox modifies a file.
#
# Parameters:
#
#   module - module's name
#   file   - file's path
#
sub updateFileDigest 
{
    my ($self, $module, $file) = @_;
    
    my $gconf = $self->{'gconfmodule'};

    my $fileEntry = {'module' => $module, 'file' => $file};
    $self->_updateMD5($fileEntry);
}

# Method: updateDigests 
#
#   This method must be called once changes have been saved to
#   update the digests.
#
sub updateDigests 
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $class = 'EBox::Module::Service';
    
    for my $mod (@{$global->modInstancesOfType($class)}) {
        for my $file (@{$mod->usedFiles()}) { 
            next unless ($self->modificationAllowed($file->{'module'},
                         $file->{'file'}));
            $self->_updateMD5($file);
        }
    }
}

# Method: updateModuleDigests 
#
#   This method must be called when the user configures a module
#   for first time. Note this function updates digest for a
#   given module while updateDigests does the same for all modules.
#
#   This function set the packages as accepted
#
# Parameters:
#
#   module - module name
#
sub updateModuleDigests 
{
    my ($self, $modName) = @_;

    my $global = EBox::Global->getInstance();
    my $gconf = $self->{'gconfmodule'};

    my $mod = $global->modInstance($modName);
    unless (defined($mod)) {
        throw EBox::Exceptions::Internal("Can't instance $modName");
    }
    my @files;
    for my $file (@{$mod->usedFiles()}) { 
        $self->_updateMD5($file);
        my $module = $file->{'module'};
        push (@files, "${module}_" . $self->_fileId($file));

    }

    $self->setAcceptedFiles(\@files, []);
}

# Method: enableAllModules
#
#	This method enables all modules implementing
#	<EBox::Module::Service>
#
sub enableAllModules
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    for my $modName (@{$self->_dependencyTree()}) {
        my $module = $global->modInstance($modName);
        $module->setConfigured(1);
        $module->enableService(1);
        $self->updateModuleDigests($modName);
        try {
            $module->enableActions();
        } otherwise {
            $module->setConfigured(undef);
            $module->enableService(undef);
            EBox::warn("Falied to enable module $modName");
        }
        $self->updateModuleDigests($modName);
    }

}

# Method: checkUserModifications
#
#     Indicate if eBox must check user modifications from
#     configuration files or not. It is defined in main eBox
#     configuration file at "/etc/ebox" by
#     "override_user_modification" value
#
# Returns:
#
#     true  - if it must check user modifications
#
#     false - otherwise
#
sub checkUserModifications
{
    my ($self) = @_;

    if (defined($self->{OVERRIDE_USER_MODIFICATIONS_KEY})) {
        return $self->{OVERRIDE_USER_MODIFICATIONS_KEY};
    }

    my $overrideUserMods =
      EBox::Config::configkey(OVERRIDE_USER_MODIFICATIONS_KEY);

    # if key is not defined or its value is different from yes, say check
    if (defined($overrideUserMods) and $overrideUserMods eq 'yes' ) {
        return 0;
    } else {
        return 1;
    }

}

# Group: Private methods

sub _dependencyTree
{
    my ($self, $tree, $hash) = @_;

    $tree = [] unless (defined($tree));
    $hash = {} unless (defined($hash));

    my $global = $self->{'gconfmodule'};

    my $numMods = @{$tree};
    for my $mod (@{$global->modInstancesOfType(CLASS)}) {
        next if (exists $hash->{$mod->{'name'}});
        my $depOk = 1;
        for my $modDep (@{$mod->enableModDepends()}) {
            unless (exists $hash->{$modDep}) {
                $depOk = undef;
                last;
            }
        }
        if ($depOk) {
            push (@{$tree}, $mod->{'name'});
            $hash->{$mod->{'name'}} = 1;
        }
    }

    if ($numMods ==  @{$tree}) {
        return $tree;
    } else {
        return $self->_dependencyTree($tree, $hash);
    }
}

sub _fileId
{
    my ($self, $file) = @_;

    unless (defined($file))  {
        throw EBox::Exceptions::MissingArgument($file);
    }

    my $gconf = $self->{'gconfmodule'};

    my $modPath = GCONF_DIR. $file->{'module'};
    for my $dir ($gconf->st_all_dirs($modPath)) {
        my $hashEntry = $gconf->st_hash_from_dir("$dir");
        next unless (exists $hashEntry->{'file'});
        return basename($dir) if ($hashEntry->{'file'} eq $file->{'file'});
    }

    # File does not exist within our database. Add new entry
    my $id = $gconf->get_unique_id('file', "$modPath");
    $gconf->st_set_string("$modPath/$id/file", $file->{'file'});
    $gconf->st_set_string("$modPath/$id/digest", "");
    $gconf->st_set_bool("$modPath/$id/accepted", undef);

    return $id;
}

sub _idToPath
{
    my ($self, $module, $id) = @_;

    my $gconf = $self->{'gconfmodule'};

    $gconf->st_get_string(GCONF_DIR . "$module/$id/file");
}

sub _fileModified 
{
    my ($self, $file) = @_;

    unless (defined($file))  {
        throw EBox::Exceptions::MissingArgument($file);
    }

    unless (defined($file->{'id'})) {
        throw EBox::Exception::Internal(
            'file must contain a valid directory id');
    }

    my $gconf = $self->{'gconfmodule'};

    my $dir = GCONF_DIR . $file->{'module'} . '/' . $file->{'id'};

    unless ($gconf->st_dir_exists($dir)) {
        throw EBox::Exceptions::Internal("$dir does not exist");
    }

    my $hashEntry = $gconf->st_hash_from_dir($dir);
    unless ($hashEntry->{'file'} eq $file->{'file'}) {
        throw EBox::Exceptions::Internal("file does not match");
    }

    my $stDigest = $hashEntry->{'digest'};
    my $currDigest = $self->_getMD5($file->{'file'});
    return  ($stDigest ne $currDigest)
}



sub _updateMD5
{
    my ($self, $file) = @_;

    unless (defined($file))  {
        throw EBox::Exceptions::MissingArgument($file);
    }

    my $gconf = $self->{'gconfmodule'};
    my $currDigest = $self->_getMD5($file->{'file'});  

    my $modPath = GCONF_DIR. $file->{'module'};
    for my $dir ($gconf->st_all_dirs($modPath)) {
        my $hashEntry = $gconf->st_hash_from_dir($dir);
        next unless (exists $hashEntry->{'file'}
                     and $hashEntry->{'file'} eq $file->{'file'});
        my $stDigest = $hashEntry->{'digest'};

        return if ($stDigest eq $currDigest);
        $gconf->st_set_string("$dir/digest", $currDigest);
        return;
    }

    my $id = $gconf->get_unique_id('file', "$modPath");
    $gconf->st_set_string("$modPath/$id/file", $file->{'file'});
    $gconf->st_set_string("$modPath/$id/digest", $currDigest);
}

sub  _getMD5
{
    my ($self, $path) = @_;

    my $exists = 1;
    try {
        root("test -e $path");
    } otherwise {
        EBox::info("File $path does not exist. So we won't compute its digest");
        $exists = undef;
    };

    unless ($exists) {
       return "notexists";
    }

    my $md5 = pop(@{root("md5sum $path | cut -d' ' -f1")});
    chomp $md5;

    return $md5;
}

1;
