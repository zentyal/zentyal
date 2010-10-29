# Copyright (C) 2010 eBox Technologies S.L.
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

use Config::Tiny;

use constant CONFIG_FILE => '/etc/zentyal-desktop/zentyal-desktop.conf';

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
sub mailProtocol
{
    my ($self) = @_;

    return $self->_getOption('mail', 'use-ssl');
}

sub _getOption # (section, option)
{
    my ($self, $section, $option) = @_;

    # First we check if the option has been overriden
    my $overriden = $self->{override}->{$section}->{$option};
    if(defined $overriden) {
        return $overriden;
    }

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

    $self->{default}->{'mail'}->{'protocol'} = 'imap';
    $self->{default}->{'mail'}->{'use-ssl'} = 'when-possible';
}

1;
