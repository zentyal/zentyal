# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::FirewallHelper;

use EBox::Gettext;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = {};
    $self->{net} = EBox::Global->modInstance('network');
    bless($self, $class);
    return $self;
}

# Method: prerouting
#
#   Rules returned by this method are added to the PREROUTING chain in
#   the NAT table. You can use them to do NAT on the destination
#   address of packets.
#
# Returns:
#
#   array ref - containing prerouting rules
sub prerouting
{
    return [];
}

# Method: postrouting
#
#   Rules returned by this method are added to the POSTROUTING chain in
#   the NAT table. You can use them to do NAT on the source
#   address of packets.
#
# Returns:
#
#   array ref - containing postrouting rules
sub postrouting
{
    return [];
}

# Method: preForward
#
#   Rules returned by this method are added to the FORWARD chain
#   before any others.
#
# Returns:
#
#   array ref - containing preForward rules
sub preForward
{
    return [];
}

# Method: forward
#
#   Rules returned by this method are added to the FORWARD chain in
#   the filter table. You can use them to filter packets passing through
#   the firewall.
#
# Returns:
#
#   array ref - containing forward rules
sub forward
{
    return [];
}

# Method: forwardNoSpoof
#
#   Rules returned by this method are added to the fnospoofmodules chain in
#   the filter table. You can use them to add exceptions on the default
#   source checking in the firewall. This is mainly used by IPsec special
#   routing rules.
#
# Returns:
#
#   array ref - containing forward no spoof rules
sub forwardNoSpoof
{
    return [];
}

# Method: forwardAccept
#
#   Rules returned by this method are inserted in reverse order in
#   faccept chain. You can use them to analyse accepted forward traffic.
#
# Returns:
#
#   array ref - containing forwardAccept rules
#
sub forwardAccept
{
    return [];
}

# Method: preInput
#
#   Rules returned by this method are added to the INPUT chain
#   before any others.
#
# Returns:
#
#   array ref - containing preInput rules
sub preInput
{
    return [];
}

# Method: input
#
#   Rules returned by this method are added to the INPUT chain for INTERNAL ifaces in
#   the filter table. You can use them to filter packets directed at
#   the firewall itself.
#
# Returns:
#
#   array ref - containing input rules
sub input
{
    return [];
}

# Method: inputNoSpoof
#
#   Rules returned by this method are added to the inospoofmodules chain in
#   the filter table. You can use them to add exceptions on the default
#   source checking in the firewall. This is mainly used by IPsec special
#   routing rules.
#
# Returns:
#
#   array ref - containing input no spoof rules
sub inputNoSpoof
{
    return [];
}

# Method: inputAccept
#
#   Rules returned by this method are inserted in reverse order in
#   iaccept chain. You can use them to analyse accepted input traffic.
#
# Returns:
#
#   array ref - containing inputAccept rules
#
sub inputAccept
{
    return [];
}

# Method: preOutput
#
#   Rules returned by this method are added to the OUTPUT chain
#   before any others.
#
# Returns:
#
#   array ref - containing preOutput rules
sub preOutput
{
    return [];
}

# Method: output
#
#   Rules returned by this method are added to the OUTPUT chain in
#   the filter table. You can use them to filter packets originated
#   within the firewall.
#
# Returns:
#
#   array ref - containing output rules
sub output
{
    return [];
}

# Method: outputAccept
#
#   Rules returned by this method are inserted in reverse order in
#   oaccept chain. You can use them to analyse accepted output traffic.
#
# Returns:
#
#   array ref - containing outputAccept rules
#
sub outputAccept
{
    return [];
}

# Method: externalInput
#
#   Rules returned by this method are added to the INPUT for EXTERNAL interfaces chain in
#   the filter table. You can use them to filter packets directed at
#   the firewall itself.
#
# Returns:
#
#   array ref - containing input rules
sub externalInput
{
    return [];
}

# Method: chains
#
#   Chains returned by this method are created and can be referenced on this helper
#   defined rules
#
# Returns:
#
#   hash ref - containing table-chain name pairs. Example:
#       { nat => ['chain1', 'chain2'], filter => ['chain3'] }
sub chains
{
    return {}
}

# Method: restartOnTemporaryStop
#
#   Determine if the firewall module must be restarted in a module
#   temporary stop
#
# Returns:
#
#   Boolean - the value. By default, it is stopped
#
sub restartOnTemporaryStop
{
    return 0;
}

# Group: Protected methods

# Method: _outputIface
#
#   Returns iptables rule part for output interface selection
#   If the interface is a bridge port it matches de whole bridge (brX)
#
# Parameters:
#
#   Iface - Iface name
#
sub _outputIface # (iface)
{
    my ($self, $iface) = @_;

    if ( $self->{net}->ifaceExists($iface) and
         $self->{net}->ifaceMethod($iface) eq 'bridged' ) {

        my $br = $self->{net}->ifaceBridge($iface);
        return  "-o br$br";
    } else {
        return "-o $iface";
    }
}
# Method: _inputIface
#
#   Returns iptables rule part for input interface selection
#   Takes into account if the iface is part of a bridge
#
# Parameters:
#
#   Iface - Iface name
#
sub _inputIface # (iface)
{
    my ($self, $iface) = @_;

    if ( $self->{net}->ifaceExists($iface) and
        $self->{net}->ifaceMethod($iface) eq 'bridged' ) {
        return  "-m physdev --physdev-in $iface";
    } else {
        return "-i $iface";
    }
}

# Method: beforeFwRestart
#
#  called before firewall module restart when it is enabled
#
#  The default implementation does nothing
#
sub beforeFwRestart
{
}

# Method: afterFwRestart
#
#  Called after firewall module restart when it is enabled
#
#  The default implementation does nothing
#
sub afterFwRestart
{
}


1;
