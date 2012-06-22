# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::RemoteServices::Reporter;

# Class: EBox::RemoteServices::Reporter
#
#       Initial class to perform the consolidation for reports
#

use warnings;
use strict;

use EBox;
use EBox::Config;

# Singleton variable
my $_instance = undef;

# Group: Public methods

sub instance
{
    unless (defined($_instance)) {
        $_instance = EBox::RemoteServices::Reporter->_new();
    }
    return $_instance;
}

# Create the object
sub _new {
    my ($class) = @_;

    my $self = { };

    bless($self, $class);

    $self->{helpers} = [];

    $self->_getHelpers();

    return $self;
}

# Method: register
#
#    Register a helper
#
# Parameters:
#
#    className - String the class name
#
# Returns:
#
#    Boolean - indicating if the registration was fine
#
sub register
{
    my ($self, $className) = @_;

    eval "use $className";
    if ($@) {
        EBox::error("Can't load $className: $!");
        return 0;
    }

    # TODO: Check duplicates
    my $obj = new $className();
    push(@{$self->{helpers}}, $obj) if ($obj->enabled());
    return 1;
}

# Method: unregister
#
#    Unregister this helper
#
# Parameters:
#
#    className - String the class name
#
sub unregister
{
    my ($self, $className) = @_;

    my @new;
    foreach my $obj (@{$self->{helpers}}) {
        next if (ref($obj) eq $className);
        push(@new, $obj);
    }
    $self->{helpers} = \@new;
}

# Method: consolidate
#
#    Go for every reporting class and perform the consolidation
#
sub consolidate
{
    my ($self) = @_;

    foreach my $helper (@{$self->{helpers}}) {
        $helper->consolidate();
    }
}

# Method: send
#
#    Send the reports to the end point
#
sub send
{
    my ($self) = @_;

    foreach my $helper (@{$self->{helpers}}) {
        $helper->send();
    }
}

# Group: Private methods

# Return the available report classes
sub _getHelpers
{
    my ($self) = @_;

    my $path = EBox::Config::perlPath() . 'EBox/RemoteServices/Reporter/';

    opendir(my $dir, $path);
    while( my $file = readdir($dir) ) {
        next unless $file =~ '.pm$';
        $file =~ s:\.pm$::g;
        # This will register the class
        my $className = "EBox::RemoteServices::Reporter::$file";
        $self->register($className);
    }
    closedir($dir);
}

1;
