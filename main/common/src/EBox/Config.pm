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

package EBox::Config;

use EBox::Exceptions::External;
use EBox::Gettext;

use Config::Tiny;

my $ref = {};
$ref->{prefix} = "/usr";
$ref->{datadir} = "/usr/share";
$ref->{sysconfdir} = "/etc";
$ref->{localstatedir} = "/var";
$ref->{libdir} = "/var/lib";

for my $key (keys(%{$ref})) {
    if (substr($ref->{$key},-1) ne '/') {
        $ref->{$key} = ($ref->{$key} . '/');
    }
}

$ref->{version} = '4.2';
$ref->{perlpath} = '/usr/share/perl5/';

my @confFiles;
my %cachedFiles;

sub refreshConfFiles
{
     @confFiles = glob(EBox::Config::etc() . '*.conf');
}

# Function: flushConfigkeys
#
#  Flushes all the cached config keys
#
sub flushConfigkeys
{
    %cachedFiles = ();
}

sub etc
{
    return $ref->{sysconfdir} . 'zentyal/';
}

sub var
{
    return $ref->{localstatedir};
}

# Function: configkeyFromFile
#
#      Get a configuration key from the specified file
#
# Parameters:
#
#      key - String the configuration key
#      file - String the configuration file path
#
# Returns:
#
#      String - the configuration value for that key if found
#
#      undef - if the configuration key is not in the configuration file
#
# Exceptions:
#
#      <EBox::Exceptions::External> - thrown if the file cannot be
#      opened
#
sub configkeyFromFile # (key, file)
{
    my ($key, $file) = @_;

    my $configKeys = configKeysFromFile($file);

    return $configKeys->{$key};
}

sub configkey # (key)
{
    my ($key) = @_;

    unless (@confFiles) {
        refreshConfFiles();
    }

    my $value = undef;
    foreach my $file (@confFiles) {
        $value = configkeyFromFile($key, $file);
        last if defined ($value);
    }
    if (defined ($value)) {
        return $value;
    } else {
        return '';
    }
}

sub boolean
{
    my ($key) = @_;

    return (configkey($key) eq 'yes');
}

sub list
{
    my ($key) = @_;

    my $val = configkey($key);
    if ($val) {
        my @values = split (' ', $val);
        return \@values;
    } else {
        return [];
    }
}

sub configkeys # (key)
{
    my ($key) = @_;

    unless (@confFiles) {
        refreshConfFiles();
    }

    my @values;
    foreach my $file (@confFiles) {
        my $value = configkeyFromFile($key, $file);
        push (@values, $value) if defined ($value);
    }
    return \@values;
}

# Function: configKeysFromFile
#
#      Get all configuration keys from a file
#
# Parameters:
#
#      file - String the configuration file path
#
# Returns:
#
#      hash ref - the keys with their values as it follows:
#
#         key - String the key name
#         value - String the value for that key
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the file cannot be
#      opened
#
sub configKeysFromFile # (file)
{
    my ($file) = @_;

    unless (exists $cachedFiles{$file}) {
        $cachedFiles{$file} = Config::Tiny->read($file) or
            throw EBox::Exceptions::External(
                    __x('Could not open the config file {file}.', file => $file));
    }

    return $cachedFiles{$file}->{_};
}

sub user
{
    my $user = configkey('user');
    $user or throw EBox::Exceptions::External(
            __('The ebox user has not been set in the config file.'));
    return $user;
}

sub gids
{
    my $user = user();
    my $gids = `/usr/bin/id -G $user`;
    chomp ($gids) if defined $gids;
    return $gids;
}

sub uid
{
    my $uid = getpwnam(user());
    return $uid;
}

sub group
{
    my $value = configkey('egroup');
    $value or throw EBox::Exceptions::External('The ebox group has not '.
            'been set in the config file.');
    return $value;
}

sub home
{
    my $user = user();
    my ($name,$passwd,$uid,$gid, $quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($user);
    return $dir;
}

sub prefix
{
    return $ref->{prefix};
}

sub share
{
    return $ref->{datadir};
}

# FIXME: is this used?
sub lib
{
    return $ref->{libdir};
}

sub scripts
{
    my ($module) = @_;

    if (defined $module) {
        return $ref->{datadir} . "zentyal-$module/";
    } else {
        return $ref->{datadir} . 'zentyal/';
    }
}

sub locale
{
    return $ref->{datadir} . 'locale/';
}

sub conf
{
    return $ref->{localstatedir} . 'lib/zentyal/conf/';
}

sub tmp
{
    return $ref->{localstatedir} . 'lib/zentyal/tmp/';
}

sub shm
{
    return '/run/shm/zentyal';
}

# Method: downloads
#
#      Get the path of the directory where the files to be downloaded are put
#
# Returns:
#
#      String - the path to that directory
sub downloads
{

    return tmp();
}

sub passwd
{
    return $ref->{localstatedir} . 'lib/zentyal/conf/ebox.passwd';
}

# Method: sessionid
#
#      Get the path where Web session identifier is stored
#
# Returns:
#
#      String - the path to that file
sub sessionid
{
    return $ref->{localstatedir} . 'lib/zentyal/conf/ebox.sid';
}

# Method: scriptSession
#
#      Get the path where the script session identifier is stored
#
# Returns:
#
#      String - the path to that file
#
sub scriptSession
{
    return $ref->{localstatedir} . 'lib/zentyal/conf/ebox.script-sid';
}

sub log
{
    return $ref->{localstatedir} . 'log/zentyal/';
}

sub logfile
{
    return $ref->{localstatedir} . 'log/zentyal/zentyal.log';
}

sub modules
{
    return $ref->{datadir} . 'zentyal/modules/';
}

sub stubs
{
    return $ref->{datadir} . 'zentyal/stubs/';
}

sub psgi
{
    return $ref->{datadir} . 'zentyal/psgi/';
}

sub cgi
{
    return $ref->{datadir} . 'zentyal/cgi/';
}

sub templates
{
    return $ref->{datadir} . 'zentyal/templates/';
}

sub schemas
{
    return $ref->{datadir} . 'zentyal/schemas/';
}

sub www
{
    return $ref->{datadir} . 'zentyal/www/';
}

sub css
{
    return $ref->{datadir} . 'zentyal/www/css/';
}

sub images
{
    return $ref->{datadir} . 'zentyal/www/images/';
}

sub dynamicwww
{
    return $ref->{localstatedir} . 'lib/zentyal/dynamicwww/';
}

sub dynamicwwwSubdirs
{
    return [ dynamicimages(), dynamicRSS() ];
}

sub dynamicimages
{
    return dynamicwww() . 'images/';
}

sub dynamicRSS
{
    return dynamicwww() . 'feed/';
}

sub version
{
    return $ref->{version};
}

sub lang
{
    return $ref->{lang};
}

# Method: perlPath
#
#      Get the PERL path where the perl modules lying on (Static
#      method).
#
# Returns:
#
#      String - the perl path
#
sub perlPath
{
    return $ref->{perlpath};
}

sub hideExternalLinks
{
    return configkey('custom_prefix');
}

sub urlEditions
{
    return 'http://bit.ly/1e83s5u';
}

1;
