# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::HA::CRMWrapper
#
#    This class is responsible to run any crm command to crmd.
#

package EBox::HA::CRMWrapper;

use EBox::Sudo;
use List::Util;

# Function: resourceNum
#
# Returns:
#
#    Int - the number of configured resources
#
sub resourceNum
{
    return scalar(@{_resources()});
}

# Function: activeNode
#
# Returns:
#
#     String - the node which owns as much resources
#
sub activeNode
{
    my @resources = @{_resources()};

    my %nodeCount;
    foreach my $r (@resources) {
        my $output = EBox::Sudo::root("crm_resource --resource '$r' --locate");
        # If it not running, then the output is on STDERR
        # Example: resource rsc_ip is NOT running
        next if (@{$output} == 0);
        my ($hostname) = $output->[0] =~ m/resource $r is running on: ([^\s]+)/;
        if (exists $nodeCount{$hostname}) {
            $nodeCount{$hostname}++;
        } else {
            $nodeCount{$hostname} = 1
        }
    }
    my $maxKey = List::Util::reduce { $nodeCount{$a} > $nodeCount{$b} ? $a : $b } keys %nodeCount;
    # It does not count if we have multiple maximums...
    return $maxKey;
}

# Procedure: promote
#
#     Move all resources to the given node and remove the condition
#     afterwards
#
#     It is currently implemented by moving every resource to
#     the given node and then removing the constraint.
#
# Parameters:
#
#     nodeName - String the node name
#
# Exceptions:
#
#     <EBox::Exceptions::Sudo::Command> - thrown if the crmd is not
#     running
#
sub promote
{
    my ($nodeName) = @_;

    my @cmds = ();
    foreach my $r (@{_resources()}) {
        push(@cmds, qq{crm_resource --resource '$r' --move --host '$nodeName'});
        push(@cmds, qq{crm_resource --resource '$r' --clear --host '$nodeName'});
    }

    EBox::Sudo::root(@cmds);

}

# Procedure: demote
#
#     Move all resources from the given node and remove the condition
#     afterwards
#
#     It is currently implemented by banning every resource from
#     the given node and then removing the constraint.
#
# Parameters:
#
#     nodeName - String the node name
#
# Exceptions:
#
#     <EBox::Exceptions::Sudo::Command> - thrown if the crmd is not
#     running
#
sub demote
{
    my ($nodeName) = @_;

    my @cmds = ();
    foreach my $r (@{_resources()}) {
        push(@cmds, qq{crm_resource --resource '$r' --ban --host '$nodeName'});
        push(@cmds, qq{crm_resource --resource '$r' --clear --host '$nodeName'});
    }

    EBox::Sudo::root(@cmds);
}

# Group: Private functions

sub _resources
{
    my $output = EBox::Sudo::root('crm_resource -l');
    my @rscs = map { chomp($_); $_ } @{$output};
    return \@rscs;
}

1;
