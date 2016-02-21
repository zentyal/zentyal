# Copyright (C) 2007 Warp Networks S.L.
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
# Class: EBox::Types::File
#
#      This type is intended to support file uploading, downloading
#      from the web interface. Its value keeps the absolute path
#      where the file is stored within the eBox machine.
#
#      If the type instance is editable, you can upload a file
#      although the file path has not changed. If non editable, the
#      viewer will only show the file absolute path.
#
#      This type has an associated action which is the
#      *download*. This action can be actived setting allowDownload
#      property as true. This will show up the action download on any
#      data model.
#

package EBox::Types::File;

use base 'EBox::Types::Abstract';

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use EBox::Sudo;

# Core modules
use File::Basename;
use TryCatch;

# Group: Public methods

# Constructor: new
#
#     Create a new <EBox::Types::File> instance
#
# Overrides:
#
#     <EBox::Types::Basic::new>
#
# Parameters:
#
#     allowDownload - Boolean indicating if the file uploaded can be
#     downloaded *(Optional)* Default value: false
#     filePath - path to the file location
#     dynamicPath - reference to a subroutine that returns the actual filePath
#     user        - user which will own the file (default: ebox)
#     group       - group which will be own the file, if it is not supplied
#                     the group will be have the sanme name than the user
#
# Returns:
#
#     <EBox::Types::File> - the file type instance
#
sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/file.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/file.mas';
    }

    $opts{'type'} = 'file';
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: printableValue
#
# Overrides:
#
#       <EBox::Types::Abstract::printableValue>
#
sub printableValue
{
    my ($self) = @_;

    my $path = $self->path();
    if ( defined ($path) ) {
        return basename($path);
    } else {
        return '';
    }
}

# Method: isEqualTo
#
# Overrides:
#
#       <EBox::Types::Abstract::isEqualTo>
#
sub isEqualTo
{
    my ($self, $new) = @_;

    my $fileExists  = $self->exist();
    my $uploadFile = (-f $new->tmpPath);
    my $removeFile =  $new->toRemove;

    if ( $fileExists and $uploadFile) {
        # Check MD5 sum to check content uniqueness
        my $path    = $self->path;
        my $tmpPath = $new->tmpPath;
        my $equal;
        try {
            EBox::Sudo::silentRoot("diff -q $path $tmpPath");
            # diff return value 0; they are equal
            $equal = 1;
        } catch {
            # diff command failed, we assume they are different (cannot find
            # a reliable documentation of diff command's return values)
            $equal = 0;
        }

        return $equal;
    } elsif ($uploadFile) {
        return 0
    } elsif ($removeFile) {
        return 0;
    }

    return 1;
}

# Method: fields
#
# Overrides:
#
#    <EBox::Types::Abstract::fields>
#
sub fields
{
    my ($self) = @_;
    my $pathField = $self->fieldName() . '_path';
    my $removeField = $self->fieldName() . '_remove';
    return ( $pathField, $removeField );
}

# Method: path
#
#    Accessor to the path value stored
#
# Returns:
#
#    String - the file path
#
sub path
{
    my ($self) = @_;

    if (exists $self->{dynamicPath}) {
        my $dynamicPathFunc = $self->{dynamicPath};
        return &$dynamicPathFunc($self);
    }

    return $self->{filePath};
}

# Method: user
#
# Returns:
#         - the user which will own the file
sub user
{
    my ($self) = @_;

    if (not exists $self->{user}) {
        return 'ebox';
    }

    return $self->{user};
}

# Method: group
#
# Returns:
#         - the group which will own the file
sub group
{
    my ($self) = @_;

    if (not exists $self->{user}) {
        return $self->user();
    }

    return $self->{user};
}

# Method: exist
#
#    Check if the file path marked exists
#
# Returns:
#
#    boolean - if the file exists given a file path
#    undef - if the file path is not set
#
sub exist
{
    my ($self, $path) = @_;
    defined $path or
        $path = $self->path();
    $path or
        return undef;

    if ( $self->path() ) {
        return EBox::Sudo::fileTest('-f', $self->path);
    } else {
        return undef;
    }
}

# Method: toRemove
#
#    Check if the file has been marked to be removed
#
# Returns:
#
#    boolean -
#
sub toRemove
{
    my ($self) = @_;

    return $self->{remove};
}

# Method: allowDownload
#
#     Check if it is possible to allow download or not from the viewer
#     point of view
#
# Returns:
#
#     Boolean - true if it is allowed, false otherwise
#
sub allowDownload
{
    my ($self) = @_;

    return $self->{allowDownload};
}

# Method: showFileWhenEditing
#
#     Show the file path name when edition is done
#
# Returns:
#
#     Boolean - true if it is shown, false otherwise
#
sub showFileWhenEditing
{
    my ($self) = @_;

    return $self->{showFileWhenEditing};
}

# Method: linkToDownload
#
#      Link to the CGI which downloads the file
#
sub linkToDownload
{
    my ($self) = @_;

    my $contextName = $self->model()->contextName();

    my $link = '/Downloader/FromModel?';
    $link .= 'model=' . $contextName;
    $link .= '&dir=' . $self->model()->directory();
    $link .= '&id=' . $self->row()->id();
    $link .= '&field='  . $self->fieldName();

    return $link;
}

# Method: tmpPath
#
#       Get the tmp path when the file is not used by the file type by
#       it is already uploaded to the server
#
# Returns:
#
#       String - the path within the tmp directory where the potential
#       file is stored
#
sub tmpPath
{
    my ($self) = @_;

    return ( EBox::Config::tmp() . $self->fieldName() . '_path' );
}

# Method: userPath
#
#       Get the user given path where the file is stored to be
#       uploaded by the browser. This returned value is useful to
#       determine if any file has been uploaded or not.
#
# Returns:
#
#       String - the user given path
#
sub userPath
{
    my ($self) = @_;

    return $self->{userPath};
}

#  Method: backupPath
#
#   return the path to the actual configuration backup
#
# Parameters:
#   path - path of the file which owns the backup, if it is not
#       provided the path() method will be used
sub backupPath
{
    my ($self, $path) = @_;
    defined $path or
      $path = $self->path();
    $path or
      return undef;

    my $backupPath = $path . '.bak';
    return $backupPath;
}

#  Method: noPreviousFilePath
#
#   return the path to the file to signals to the actual configuration backup
#   that there wasn't any file before
#
# Parameters:
#   path - path of the file which owns the backup, if it is not
#       provided the path() method will be used
sub noPreviousFilePath
{
    my ($self, $path) = @_;
    defined $path or
      $path = $self->path();
    $path or
      return undef;

    my $backupPath = $path . '.noprevious.bak';
    return $backupPath;
}

# Method: backupFiles
#
#   Make an actual configuration backup of the file.. This backup will used to
#   discard changes when revoking the configuration
#
# Parameters:
#   path - path of the file which owns the backup, if it is not
#       provided the path() method will be used
sub backupFiles
{
    my ($self, $path) = @_;
    defined $path or
      $path = $self->path();
    $path or return;

    my $backupPath = $self->backupPath($path);
    my $noPreviousFilePath = $self->noPreviousFilePath($path);

    if ($self->exist($path)) {

        $backupPath or return;

        EBox::Sudo::root("cp -p $path $backupPath");
        EBox::Sudo::root("rm -f $noPreviousFilePath");
    } else {
        EBox::Sudo::root("touch $noPreviousFilePath");
        EBox::Sudo::root("rm -f $backupPath");
    }

}

# Method: restoreFiles
#
#  Restores the actual configuration backup of the file, thus discarding last
#  changes
#
# Parameters:
#   path - path of the file which owns the backup, if it is not
#       provided the path() method will be used
sub restoreFiles
{
    my ($self, $path) = @_;
    defined $path or
      $path = $self->path();
    $path or return;

    my $backupPath = $self->backupPath($path);
    if ( EBox::Sudo::fileTest('-f', $backupPath) ) {
        EBox::Sudo::root("cp -p $backupPath $path");
        return;
    }

    my $noPreviousFilePath = $self->noPreviousFilePath($path);
    if ( EBox::Sudo::fileTest('-f', $noPreviousFilePath) ) {
        EBox::Sudo::root("rm -f $path");
    }
}

# Group: Protected methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown if the move cannot be
#       done
#
sub _setMemValue
{
    my ($self, $params) = @_;

    my $homePathParam = $self->fieldName() . '_path';
    my $removeParam = $self->fieldName() . '_remove';

    # Chrome adds C:\fakepath\ to the file path for security reasons
    my $path = $params->{$homePathParam};
    $path =~ s/^c:\\fakepath\\//i;

    $self->{userPath} = $path;
    $self->{remove} = $params->{$removeParam};
}

# Method: _storeInHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInHash>
#
sub _storeInHash
{
    my ($self, $hash) = @_;

    my $keyField = $self->fieldName() . '_path';

    if ($self->path() and $self->userPath()) {
        # Do actually move
        $self->_moveToPath();

        $hash->{$keyField} = $self->path();
    } elsif ($self->{remove}) {
        delete $hash->{$keyField};
        if (not $self->userPath()) {
            # Actually remove
            my $path = $self->path();
            if (-f $path) {
                EBox::Sudo::root("rm $path");
            }
        }
    }
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
    my ($self, $hash) = @_;

    my $pathField = $self->fieldName() . '_path';
    $self->{filePath} = $hash->{$pathField};
}

# Method: allowUnsafeChars
#
# Overrides:
#
#       <EBox::Types::Abstract::allowUnsafeChars>
#
sub allowUnsafeChars
{
    return 1;
}

# Method: _paramIsValid
#
#       Every file which exists (defined by
#       <EBox::Types::File::_paramIsSet> is valid. The subclasses may
#       override this method to check any content of the file.
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    # Check if the parameter exist
    my $path =  $self->fieldName() . '_path';
    my $pathValue = $params->{$path};
    my $remove =  $self->fieldName() . '_remove';
    my $removeValue = $params->{$remove};

    return 1 if ($removeValue);
    return 1 if (defined ( $pathValue ));
    return (-f $self->tmpPath());
}

# Method: _setValue
#
#    Set the value for the file.
#
#    Two choices are available:
#
#         - give a path where the file will be stored (given a
#         non-empty string). The file must be set in
#         <EBox::Config::tmp> and the name must match "$fieldName" + '_path'
#
#         - remove the current value passing (given an empty string or undef)
#
# Overrides:
#
#    <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#    value - String the path to store in file type or an empty string
#    to remove it
#
sub _setValue #(value)
{
    my ($self, $value) = @_;

    my $params = {};
    if ( $value ) {
        $params->{$self->fieldName() . '_path'} = $value;
    } else {
        $params->{$self->fieldName() . '_remove'} = $value;
    }

    $self->setMemValue($params);
}

# Group: Private methods

sub _moveToPath
{
    my ($self) = @_;

    my $path   = $self->path();

    my $tmpPath = $self->tmpPath();
    if (not -f $tmpPath) {
        throw EBox::Exceptions::Internal("No file found at $tmpPath for moving to $path");
    }

    my $user = $self->user();
    my $group = $self->group();
    unless (($user eq 'ebox') and ($group eq 'ebox')) {
        unless (($user eq  'root') or ($group eq 'root')) {
            throw EBox::Exceptions::NotImplemented(
                "user and group combination ($user:$group) not supported"
           );
        }
    }

    EBox::Sudo::root("mv '$tmpPath' '$path'");
    try {
        EBox::Sudo::root("chown $user.$group '$path'");
    } catch ($e) {
        EBox::Sudo::root("rm -f '$path'");
        $e->throw();
    }
}

1;
