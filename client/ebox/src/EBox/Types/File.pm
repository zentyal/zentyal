# Copyright (C) 2007 Warp Networks S.L.
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

use strict;
use warnings;

use base 'EBox::Types::Abstract';

# eBox uses
use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;

# Core modules
use File::Basename;
use File::Copy::Recursive;
use Digest::MD5;

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

    if ( defined ($self->{filePath}) ) {
        return basename($self->{filePath});
    } else {
        return '';
    }

}

# Method: isEqualTo
#
# Overrides:
#
#       <EBox::Types::Abstract::compareToHash>
#
sub isEqualTo
{
    my ($self, $new) = @_;


    if ( defined ( $self->path() ) and $self->path() ne ''
         and (-f $self->path()) and defined ( $new->tmpPath() )
         and (-f $new->tmpPath())) {
        # Check MD5 sum to check content uniqueness
        my ($origFile, $newFile);
        my $origMD5 = Digest::MD5->new();
        open ($origFile, '<', $self->path());
        binmode ( $origFile );
        $origMD5->addfile($origFile);
        my $origDigest = $origMD5->hexdigest();
        my $newMD5 = Digest::MD5->new();
        open ( $newFile, '<', $new->tmpPath());
        binmode ( $newFile );
        $newMD5->addfile($newFile);
        my $newDigest = $newMD5->hexdigest();
        close($origFile);
        close($newFile);

        return ($origDigest eq $newDigest);

    } elsif ($self->exist() 
             and (not -f $new->tmpPath() and not $new->toRemove())) {

        return 1;
    }
    return 0;

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
    my ($self) = @_;

    if ( $self->path() ) {
        return (-f $self->path());
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

    my $modelDomain = $self->model()->modelDomain();
    my $modelName = $self->model()->name();
    my $index = $self->model()->index();

    unless (defined($modelDomain) and length ($modelDomain) > 0) {
        $modelDomain = undef;
    }

    unless (defined($modelName) and length ($modelName) > 0) {
        $modelName = undef;
    }

    unless (defined($index) and length ($index) > 0) {
        $index = undef;
    }


    my $link = '/ebox/Controller/Downloader/FromModel?';
    $link .= 'model=';
    $link .= "/$modelDomain" if ($modelDomain);
    $link .= "/$modelName" if ($modelName);
    $link .= "/$index" if ($index);
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

    $self->{userPath} = $params->{$homePathParam};
    $self->{remove} = $params->{$removeParam};

}

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{
    my ($self, $gconfmod, $key) = @_;

    my $keyField = "$key/" . $self->fieldName() . '_path';

    if ($self->path() and $self->userPath()) {
        $gconfmod->set_string($keyField, $self->path());
        # Do actually move
        my $tmpPath = $self->tmpPath();
        if ( -f $tmpPath ) {
            File::Copy::move($tmpPath, $self->path()) or
                throw EBox::Exceptions::Internal("Cannot move from $tmpPath "
                                                 . ' to ' . $self->path());
        }

    } elsif ($self->{remove}) {
        $gconfmod->unset($keyField);
        if ( not $self->userPath() ) {
            # Actually remove
            if ( -f $self->path() ) {
                unlink( $self->path() ) or
                  throw EBox::Exceptions::Internal('Cannot unlink '
                                                   . $self->path());
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



sub backupPath
{
  my ($self) = @_;
  my $path = $self->path();
  $path or return undef;

  my $backupPath = $path . '.bak';
  return $backupPath;
}

sub noPreviousFilePath
{
  my ($self) = @_;
  my $path = $self->path();
  $path or return undef;

  my $backupPath = $path . '.noprevious.bak';
  return $backupPath;
}


#  in backup and restore method is assummed that all files are owned by ebox
sub backup
{
  my ($self) = @_;
  my $path        = $self->path();
  $path or return;

  if ($self->exist()) {
    my $backupPath = $self->backupPath();
    $backupPath or return;

     File::Copy::Recursive::fcopy ($path, $backupPath);
  }
  else {
    my $noPreviousFilePath = $self->noPreviousFilePath();
    open my $FH, ">$noPreviousFilePath" or
      throw EBox::Exceptions::Internal("Cannot open $noPreviousFilePath: $!");
    close $FH or
      throw EBox::Exceptions::Internal("Cannot close $noPreviousFilePath: $!");
  }

}


sub restore
{
  my ($self) = @_;

  my $path = $self->path();
  $path or return;

  my $backupPath = $self->backupPath();
  if (-f $backupPath) {
    copy ($backupPath, $path);
    return;
  }
  
  my $noPreviousFilePath = $self->noPreviousFilePath();
  if (-f $noPreviousFilePath) {
    unlink $path;
    unlink $noPreviousFilePath;
  }
  


}

1;
