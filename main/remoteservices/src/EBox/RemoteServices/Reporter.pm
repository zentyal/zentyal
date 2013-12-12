# Copyright (C) 2012-2012 Zentyal S.L.
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
#       Initial class to perform everything related to reports.
#
#       - Log data for reporting
#       - Perform the consolidation
#       - Send consolidated results to the cloud
#

use warnings;
use strict;

use EBox;
use EBox::Config;
use EBox::DBEngineFactory;

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

    # Easily to parallel
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

# Method: log
#
#    Log the data for the reports from any helper
#
sub log
{
    my ($self) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();

    foreach my $helper (@{$self->{helpers}}) {
        my $data = $helper->log();
        # Not necessary to add the timestamp (Auto-added by DB)
        foreach my $row ( @{$data} ) {
            $db->insert( $helper->name(), $row);
        }
    }
    $db->do('SET NAMES UTF8'); # I'm assuming correctly, everything is UTF8
    # Perform the buffered inserts done above
    $db->multiInsert();
}

# Method: helpersNum
#
# Returns:
#
#     Int - the number of available helpers
#
sub helpersNum
{
    my ($self) = @_;

    return scalar(@{$self->{helpers}});
}

# Method: lastConsolidationTime
#
#     Check any enabled helper to get the last consolidation value
#
# Returns:
#
#     Int - the number of seconds since epoch from the last
#     consolidation time
#
sub lastConsolidationTime
{
    my ($self) = @_;

    my $last = undef;
    foreach my $helper (@{$self->{helpers}}) {
        my $helperTime = $helper->consolidationTime();
        $last = $helperTime if ( defined($helperTime) and ($helperTime > $last));
    }
    return $last;
}

# Group: Private methods

# Return the available report classes
sub _getHelpers
{
    my ($self) = @_;

    my $path = EBox::Config::perlPath() . 'EBox/Reporter/';

    opendir(my $dir, $path);
    while( my $file = readdir($dir) ) {
        next unless $file =~ '.pm$';
        $file =~ s:\.pm$::g;
        # This will register the class
        my $className = "EBox::Reporter::$file";
        $self->register($className);
    }
    closedir($dir);
}

1;
