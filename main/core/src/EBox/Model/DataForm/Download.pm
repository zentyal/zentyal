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

# Class: EBox::Model::DataFormDownload
#
# An specialized model from <EBox::Model::DataForm::Action>
# which is used to download a file from an action form.
#
# It redirects the response to <EBox::CGI::Downloader::FromTempDir>
# to download a file from EBox::Config::tmp()
#
# How to use it?
#
#   Extends this model with your custom model.
#
#   Implement formSubmitted(). Do your stuff and create a file in
#   EBox::Config::tmp() . '/downloads/' . your_file_name
#
#   At the end of this method call pushFileToDownload(your_file_name);
#
#

use strict;
use warnings;

package EBox::Model::DataForm::Download;

use base 'EBox::Model::DataForm::Action';

# eBox Exceptions
use EBox::Exceptions::MissingArgument;

# Core modules
use TryCatch;
use constant URL_REDIRECT => '/Downloader/FromTempDir?filename=';

# Group: Public methods

# Constructor: new
#
#       Create the <EBox::Model::DataForm::Download> model instance
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: pushFileToDownload
#
#   Push a file to be downloaded
#
# Parameters:
#
#   file - file name. This file must live under EBox::Config::tmp() .
#   '/downloads', typically /var/lib/zentyal/tmp/downloads/
#
#   You do not have to use the whole path, only the file name
sub pushFileToDownload
{
    my ($self, $file) = @_;

    unless (defined($file)) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    $self->pushRedirection(URL_REDIRECT . $file);
}

1;
