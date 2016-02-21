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

# Class: EBox::Downloader::CGI::FromTempDir
#
#   This class is a subclass of <EBox::Downloader::CGI::Base>
#   to download files from EBox::Config::tmp()
#
use strict;
use warnings;

package EBox::Downloader::CGI::FromTempDir;

use base 'EBox::Downloader::CGI::Base';

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

# Core modules
use TryCatch;
use Cwd 'abs_path';

# Group: Public methods

# Constructor: new
#
#      Create a <EBox::Downloader::CGI:FromTempDir>
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument> - If filename is not passsed
#   <EBox::Exceptions::Internal> - If file can't be read or is an invalid path
#
sub new # (cgi=?)
{

    my ($class, %params) = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return  $self;
}

# Group: Protected methods

# Method: _path
#
#   This method must be overriden by subclasses to return the path
#   of the file to download
#
# Exceptions:
#
#      <EBox::Exceptions::NotImplemented> - thrown if this method
#      is not implemented by the subclass
sub _path
{
    my ($self) = @_;

    return $self->{path};
}

# Method: _process
#
# Overrides:
#
#      <EBox::Downloader::CGI::Base::_process>
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if the field name is not
#      contained in the given model
#
sub _process
{
    my ($self) = @_;

    $self->_requireParam('filename');
    my $filename = $self->param('filename');

    my $downloadDir =  EBox::Config::downloads();
    my $path = $downloadDir . $filename;
    my $normalized = abs_path($path);
    unless ($normalized) {
        throw EBox::Exceptions::Internal("Path $path cannot be normalized");
    }
    unless ($normalized =~ /^$downloadDir/) {
        throw EBox::Exceptions::Internal("$normalized is not a valid path");
    }
    unless (-r $normalized) {
        throw EBox::Exceptions::Internal("$normalized can't be read");
    }
    $self->{path} = $normalized;

    $self->SUPER::_process(@_);
}

# Method: _print
#
# Overrides:
#
#      <EBox::Downloader::CGI::Base::_print>
#
# To remove the file after it has been downloaded
#
sub _print
{
    my ($self, @params) = @_;

    $self->SUPER::_print(@params);

    unlink ($self->{path}) if ( -e $self->{path} );
}

1;

