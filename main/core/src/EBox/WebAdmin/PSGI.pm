# Copyright (C) 2010-2014 Zentyal S.L.
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

package EBox::WebAdmin::PSGI;

# Package: EBox::WebAdmin::PSGI
#
#    Package in charge of managing PSGI applications inside WebAdmin
#    PSGI application

use EBox::Config;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;

use File::Slurp;
use JSON::XS;

use constant WEBADMIN_DIR => EBox::Config::conf() . 'webadmin/';
use constant APPS_FILE => WEBADMIN_DIR . 'psgi-subapps.yaml';

# Group: Public methods

# Procedure: addSubApp
#
#    Add a new sub PSGI app
#
# Parameters:
#
#    url - String the url to mount this app
#
#    appName - String the app name to get the code ref for PSGI app
#
# Exceptions:
#
#    <EBox::Exceptions::DataExists> - thrown if the url does already
#    exists
#
sub addSubApp
{
    my ($url, $appName) = @_;

    my $json = _read();
    if (exists $json->{$url}) {
        throw EBox::Exceptions::DataExists(data => 'url', value => $url);
    }
    $json->{$url} = $appName;
    _write($json);
}

# Procedure: removeSubApp
#
#    Remove a sub PSGI app
#
# Parameters:
#
#    url - String the url to mount this app
#
# Exceptions:
#
#    <EBox::Exceptions::DataNotFound> - thrown if the url does not exist
#
sub removeSubApp
{
    my ($url) = @_;

    my $json = _read();
    unless (exists $json->{$url}) {
        throw EBox::Exceptions::DataNotFound(data => 'url', value => $url);
    }
    delete $json->{$url};
    _write($json);
}

# Function: subapps
#
# Returns:
#
#    Array ref - containing hash ref with the following keys:
#
#      - url: String the url to mount the app
#      - app: Code ref the PSGI app subroutine
#
sub subapps
{
    my $json = _read();

    my @res;
    while (my ($url, $appName) = each %{$json}) {
        my @appNameParts = split('::', $appName);
        my $appRelativeName = pop(@appNameParts);
        my $pkgName = join('::', @appNameParts);
        eval "use $pkgName";
        push(@res, {'url' => $url,
                    'app' => UNIVERSAL::can($pkgName, $appRelativeName)});
    }
    return \@res;
}

# Group: Private methods

# Read the file
sub _read
{
    my ($json) = {};
    if (-e APPS_FILE) {
        ($json) = new JSON::XS->decode(File::Slurp::read_file(APPS_FILE));
    }
    return $json;
}

# Write the file
sub _write
{
    my ($json) = @_;

    unless (-d WEBADMIN_DIR) {
        mkdir(WEBADMIN_DIR);
    }
    File::Slurp::write_file(APPS_FILE, new JSON::XS->encode($json));
}

1;
