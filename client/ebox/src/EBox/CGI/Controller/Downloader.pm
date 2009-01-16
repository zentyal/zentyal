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

# Class: EBox::CGI::Controller::Downloader
#
# This CGI is used to download a file from a type called Type.

package EBox::CGI::Controller::Downloader;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;

# Core modules
use File::Basename;
use Error qw(:try);

# Dependencies
use File::MMagic;

# Group: Public methods

# Constructor: new
#
#      Create a <EBox::CGI::Controller::Downloader>
#
# Parameters:
#
#      model - <EBox::Model::DataTable> the model instance from where
#      gets the file type
#
#      id - String the row identifier from where to get the file. This
#      field is *optional* when the model has one single row
#
#      fieldName - String the field name which corresponds to the file
#      to download
#
#      - Named parameters
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if model or
#     fieldName is not present
#
sub new # (cgi=?)
{

    my ($class, %params) = @_;
    my $model = delete $params{model};
    throw EBox::Exceptions::MissingArgument('model')
      unless defined ( $model );
    my $id = delete $params{id};
    my $fieldName = delete $params{fieldName};
    throw EBox::Exceptions::MissingArgument('fieldName')
      unless defined ( $fieldName );
    my $self = $class->SUPER::new(@_);
    $self->{model} = $model;
    $self->{id} = $id;
    $self->{fieldName} = $fieldName;
    bless($self, $class);
    return  $self;
}

# Group: Protected methods

# Method: _process
#
# Overrides:
#
#      <EBox::CGI::ClientRawBase::_process>
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if the field name is not
#      contained in the given model
#
sub _process
{
    my ($self) = @_;

    my $model = $self->{model};
    my $fieldName = $self->{fieldName};
    my $id = $self->{id};

    my $row = $model->row($id);

    my $fileType = $row->{valueHash}->{$fieldName};
    unless ( defined ( $fileType )) {
        throw EBox::Exceptions::Internal("$fieldName does not exist"
                                         . 'in model ' . $model->name()
                                         . '.Possible values: ' 
                                         . join(', ', keys(%{$row->{valueHash}})));
    }
    unless ( $fileType->allowDownload() ) {
        throw EBox::Exceptions::Internal('Try to download a field which is not '
                                         . 'allowed to download from');
    }

    my $path = $fileType->path();
    # Setting the file
    $self->{downfile} = $path;
    # Setting the file name
    $self->{downfilename} = fileparse($path);

}

# Method: _print
#
# Overrides:
#
#     <EBox::CGI::ClientRawBase::_print>
#
sub _print
{
    my ($self) = @_;

    if ( $self->{error} or not defined($self->{downfile})) {
        $self->SUPER::_print();
        return;
    }

    # Try to guess MIME type
    my $mm = new File::MMagic();
    my $mimeType = $mm->checktype_filename($self->{downfile});

    print($self->cgi()->header(-type => $mimeType,
                               -attachment => $self->{downfilename},
                               -Content_length => (-s $self->{downfile})),
         );

    open( my $downFile, '<', $self->{downfile}) or
      throw EBox::Exceptions::Internal('Could open file ' .
                                       $self->{downfile} . " $!");

    # Efficient way to print a whole file
    print do { local $/; <$downFile> };

    close($downFile);

}

1;

