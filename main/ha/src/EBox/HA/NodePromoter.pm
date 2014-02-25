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

# Class: EBox::HA::NodePromoter
#
#    This class is responsible to promote and demote a node
#

package EBox::HA::NodePromoter;

use EBox::Exceptions::Sudo::Command;
use EBox::HA::ClusterStatus;
use EBox::Sudo;
use XML::LibXML;
use TryCatch::Lite;

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
    my $clusterStatus = new EBox::HA::ClusterStatus();

    foreach my $r (@{_simpleResources()}) {
        my $resourceStatus = $clusterStatus->resourceByName($r);
        my @runningNodes = @{ $resourceStatus->{nodes} };

        if (not ($nodeName ~~ @runningNodes)) {
            push(@cmds,
                 qq{crm_resource --resource '$r' --move --host '$nodeName'},
                 'sleep 3',
                 qq{crm_resource --resource '$r' --clear --host '$nodeName'});
        }
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
    foreach my $r (@{_simpleResources()}) {
        push(@cmds, qq{crm_resource --resource '$r' --ban --host '$nodeName'});
        push(@cmds, qq{sleep 3});  # Wait for the resource to stop in the local node
        push(@cmds, qq{crm_resource --resource '$r' --clear --host '$nodeName'});
    }

    EBox::Sudo::root(@cmds);
}

# Group: Private functions

# Simple resources avoid M-S and clone ones
# Return the list of resources names
sub _simpleResources
{
    # Get the resource configuration from the cib directly
    my $output = EBox::Sudo::root('cibadmin --query --scope resources');
    my $outputStr = join('', @{$output});
    my $dom =  XML::LibXML->load_xml(string => $outputStr);
    my @primitivesElems = $dom->findnodes('/resources/primitive');

    my @primitives = map { $_->getAttribute('id') } @primitivesElems;
    return \@primitives;
}

1;
