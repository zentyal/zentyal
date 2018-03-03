# Copyright (C) 2013-2014 Zentyal S.L.
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

package EBox::Downloader::CGI::RPCCert;

use base 'EBox::Downloader::CGI::Base';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::External;

use File::Basename;

sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: _path
#
# Overrides:
#
#   <EBox::Downloader::CGI::Base::_path>
#
sub _path
{
    my $ca = EBox::Global->getInstance()->modInstance('ca');
    my $caMetadata = $ca->getCACertificateMetadata();
    return $caMetadata->{path};
}

# Method: _process
#
#   Make sure the CA is available
#
# Overrides:
#
#   <EBox::Downloader::CGI::Base::_process>
#
sub _process
{
    my ($self) = @_;

    my $ca = EBox::Global->getInstance()->modInstance('ca');
    if (not $ca->isAvailable()) {
        throw EBox::Exceptions::External(
            __('Cannot get the CA certificate as it is not available'));
    }
    $self->SUPER::_process();

    # Use .crt extension to ease Windows import
    my ($filename, $directories, $suffix) = fileparse($self->{downfile}, qr/\.[^.]+$/);
    if ($suffix ne 'crt') {
        $self->{downfilename} = "${filename}.crt";
    }
}

1;
