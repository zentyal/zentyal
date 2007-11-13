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
        return $self->{filePath};
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
         and defined ( $new->path() ) and $new->path() ne '' ) {
        # Check MD5 sum to check content uniqueness
        my ($origFile, $newFile);
        my $origMD5 = Digest::MD5->new();
        open ($origFile, '<', $self->path());
        binmode ( $origFile );
        $origMD5->addfile($origFile);
        my $origDigest = $origMD5->hexdigest();
        my $newMD5 = Digest::MD5->new();
        open ( $newFile, '<', $self->_tmpPath());
        binmode ( $newFile );
        $newMD5->addfile($newFile);
        my $newDigest = $newMD5->hexdigest();
        return ($origDigest eq $newDigest);

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
    return ( $pathField );
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

    return $self->{filePath};

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

    my $link = '/ebox/';
    $link .= $self->model()->modelDomain() . '/Controller/';
    $link .= $self->model()->name() . '/';
    $link .= $self->model()->index() . '/' if defined ( $self->model()->index());
    $link .= 'Download/';
    $link .= $self->row()->{id} . '/' . $self->fieldName();

    return $link;
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

    EBox::debug('path: ' . $self->path());
    if ($self->path()) {
        $gconfmod->set_string($keyField, $self->path());
        # Do actually move
        my $tmpPath = $self->_tmpPath();
        EBox::debug("tmpPath: $tmpPath");
        if ( -f $tmpPath ) {
            EBox::debug("Moving from $tmpPath to " . $self->path());
            File::Copy::move($tmpPath, $self->path()) or
                throw EBox::Exceptions::Internal("Cannot move from $tmpPath "
                                                 . ' to ' . $self->path());
        }

    } else {
        $gconfmod->unset($keyField);
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

    return 0 unless defined ( $pathValue );

    return (-f $self->_tmpPath());

}

# Group: Private methods

# Get the tmp path when the file is not used by the file type
sub _tmpPath
{
    my ($self) = @_;

    return ( EBox::Config::tmp() . $self->fieldName() . '_path' );
}

1;
