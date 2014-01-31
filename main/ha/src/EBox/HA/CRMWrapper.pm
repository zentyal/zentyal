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

use EBox::Exceptions::Sudo::Command;
use EBox::Sudo;
use XML::LibXML;
use TryCatch::Lite;

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

# Function: monDoc
#
#     Return the crm_mon -X output in a DOM XML document
#
# Returns:
#
#     <XML::LibXML::Document> - the crm_mon data
#
sub monDoc
{
    my $output = EBox::Sudo::root('crm_mon -X');
    my $outputStr = join('', @{$output});
    return XML::LibXML->load_xml(string => $outputStr);
}

# Function: nodesStatus
#
#     Get the current node status
#
# Returns:
#
#     Hash ref - containing the node indexed by name with the current
#     status in a hash ref with the following keys:
#
#         - name : node name
#         - id: node id
#         - online: Boolean
#         - standby: Boolean
#         - resources_running: Int <number_rsc>
#         - is_dc: Boolean
#
sub nodesStatus
{
    my $dom = monDoc();
    my $nodeElms = $dom->findnodes('//nodes/node');
    my %ret;
    foreach my $nodeEl (@{$nodeElms}) {
        my $name = $nodeEl->getAttribute('name');
        $ret{$name} = { name    => $name,
                        id      => $nodeEl->getAttribute('id'),
                        online  => ($nodeEl->getAttribute('online') eq 'true'),
                        standby => ($nodeEl->getAttribute('standby') eq 'true'),
                        resources_running => $nodeEl->getAttribute('resources_running') + 0,
                        is_dc   => ($nodeEl->getAttribute('is_dc') eq 'true')
                      };
    }

    return \%ret;
}

# Function: currentDCNode
#
#      Return the current Designated Controller node
#
# Returns:
#
#      String - the node name
#
sub currentDCNode
{
    my $dom = monDoc();

    my ($dcElement) = $dom->findnodes('//summary/current_dc');
    if ($dcElement and $dcElement->getAttribute('present') eq 'true') {
        return $dcElement->getAttribute('name');
    }
    return undef;
}

# Function: activeNode
#
# Parameters:
#
#     nodesStatus - Hash ref *(Optional)* Default value: nodesStatus()
#                   is called
#
# Returns:
#
#     String - the node which owns as much resources
#
sub activeNode
{
    my ($nodesStatus) = @_;

    unless (defined ($nodesStatus)) {
        $nodesStatus = nodesStatus();
    }

    my @byRscRunning = sort { $b->{resources_running} <=> $a->{resources_running} } values %{$nodesStatus};

    return $byRscRunning[0]->{name};
}

# Function: nodeOnline
#
#
# Parameters:
#
#     nodeName    - String the node name to check its status
#
#     nodesStatus - Hash ref *(Optional)* Default value: nodesStatus()
#                   is called
#
# Returns:
#
#     String - the node which owns as much resources
#
sub nodeOnline
{
    my ($nodeName, $nodesStatus) = @_;

    unless (defined ($nodesStatus)) {
        $nodesStatus = nodesStatus();
    }

    return 0 unless (exists $nodesStatus->{$nodeName});
    return $nodesStatus->{$nodeName}->{online};
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
    foreach my $r (@{_simpleResources()}) {
        my $node = _locateResource($r);
        if (not defined($node) or ($node ne $nodeName)) {
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

# Raw resources
sub _resources
{
    try {
        my $output = EBox::Sudo::root('crm_resource -l');
        my @rscs = map { chomp($_); $_ } @{$output};
        return \@rscs;
    } catch (EBox::Exceptions::Sudo::Command $e) {
        # Assuming no resources
        return [];
    }
}

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

# Locate a resource based on info from monDoc
# Return undef if the resource is stopped
sub _locateResource
{
    my ($rscName) = @_;
    my $dom = monDoc();
    my ($elem) = $dom->findnodes("//resource[\@id='$rscName']");
    if (defined($elem) and $elem->getAttribute('role') eq 'Started') {
        return $elem->childNodes()->get_node(2)->getAttribute('name');
    }
    return undef;
}

1;
