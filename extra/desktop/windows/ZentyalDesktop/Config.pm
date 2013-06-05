# Copyright (C) 2010-2013 Zentyal S.L.
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

package ZentyalDesktop::Config;

use strict;
use warnings;

use base 'Exporter';

use Config::Tiny;

our @EXPORT_OK = qw(ZENTYAL_ICON_DATA DATA_DIR TEMPLATES_DIR);

use constant ZENTYAL_ICON_DATA => "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACsElEQVQ4jYVTS0wTURR9YVXpvMJ0ZmICDP241ZUaN2z8kBgTFy6ItECAIMF+LMy8UWhkgSCG2klUXLFQNsQNSRNTWmhIUD4m3RAtCSFC+CYYUjpvFl1oaHKfiwbip+LZ3nvOuefeXIRKIPJernoel+9GpquvmwGLg6pcF9W482wAlZXqP8GzWLWgJ+U3elLO60kZoomaz1TBfVTDzNRwgRK8mCPll0uSX0yddUcT8paerIWRuIMNx5xsaNKV2fbx4b0Qzw6UCmYQG1CN+04VrvEv52hC3oomZBiOOVn/hAvUMTeERt2LC03Cg0+tEqx0irAb4tmhagOT4CNDsd48EYgm5Ld6shaGY07WO+6C4EvXfFfEfem4Hr+NxZRHGk23i4WdIA85FYNJ8FbWjzj0NF5TrSfl/EjcwfoniuS2AaelVMyUR3q83CHCfk8lMwkGqli9KDolN+rJ4ujqmBvu6ecunrboD83SxmbADgbBYBJuAkUSVfXRqZovQ5OuTOi1e+HUMyGEZj3iwzWfmMmqeMVQuUFkBiyOnIL7tn18eMErBP8nkPII11a7hHBWxeGcYr2BKOHuUw2zvRDPlloliN3BwmkCc03SzIa/GIFqOIGoYr1garhwoFSwlU4RUl7h1b/I0w18XbpNgr1unlGCgRL8CLEBVEY1vGQQG+yGeJZuFwspjxD+kxxv4OvmW6SDdZ8dsqqNUWLLfyMWB0IIoVz3mSsm4X4cqjbYCfKw3CHCxxbp66xX1Ga84tW5Zmk63SbBus8OB0oFowSDqXGDvzlQxeo1CT7KqRj2eyrZZsAOaz4xs9olhDf8dtjr5lnRGYOh4vGSj0XV8lsmwdsmwWAQDIcEZ7IqDhvFvECJLW8QbujUr8z6EUeJtYkS7p1JuCcGsdZTgpNUw73mceZf8BMxe1ZixOqkKgAAAABJRU5ErkJggg==";

use constant DATA_DIR => $ENV{ProgramFiles} . '\Zentyal Desktop';
use constant TEMPLATES_DIR => DATA_DIR . '\templates';

use constant CONFIG_FILE =>  DATA_DIR . '\zentyal-desktop.ini';

my $singleton;

# Method: instance
#
#   Returns a reference to the singleton object of this class
#
# Returns:
#
#   ref - the class unique instance of type <ZentyalDesktop::Config>.
#
sub instance
{
    my $class = shift;

    unless (defined $singleton) {
        my $self = {};

        if (-r CONFIG_FILE) {
            $self->{config} = Config::Tiny->read(CONFIG_FILE);
        }

        $singleton = bless($self, $class);

        $singleton->_setDefaults();
    }

    return $singleton;
}

# Method: mailProtocol
#
#   Gets the value of the protocol for mail retrieving
#
# Returns:
#
#   string - Value for the option.
#
sub mailProtocol
{
    my ($self) = @_;

    return $self->_getOption('mail', 'protocol');
}

# Method: mailSSL
#
#   Gets if SSL has to be used for mail retrieving
#
# Returns:
#
#   string - (always | when-possible | never)
#
sub mailSSL
{
    my ($self) = @_;

    return $self->_getOption('mail', 'use-ssl');
}


sub setAppData
{
    my ($self, $file) = @_;

    $self->{appData} = $file;
}

sub appData
{
    my ($self) = @_;

    return $self->{appData};
}

sub setFirefoxBookmarksFile
{
    my ($self, $file) = @_;

    $self->{bookmarks} = $file;
}

sub firefoxBookmarksFile
{
    my ($self) = @_;

    return $self->{bookmarks};
}

sub _getOption # (section, option)
{
    my ($self, $section, $option) = @_;

    # If not we look it in the configuration file
    my $config = $self->{config}->{$section}->{$option};
    if (defined $config) {
        return $config;
    }

    # If not in config, return default value.
    return $self->{default}->{$section}->{$option};
}

sub _setDefaults
{
    my ($self) = @_;

}

1;
