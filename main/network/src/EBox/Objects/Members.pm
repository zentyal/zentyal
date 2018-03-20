# Copyright (C) 2012-2018 Zentyal S.L.
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

# Class EBox::Objects::Members
#
#  This class represents the members of a object. It is an array with a element
#  for each member. Each member contains a hash with this keys:
#
#            'name' - member name
#            'type' - either 'ipaddr' or 'iprange;
#             ipaddr type additional keys:
#               'ipaddr' - ip/s member (CIDR notation)
#               'mask'   -  network mask's member
#               'macaddr' -  mac address' membe (could be empty if not defined for the member)
#             iprange type additional keys:
#               'begin' - ip which marks the begins of the range (no mask)
#               'end' - ip which marks the begins of the range (no mask)

use strict;
use warnings;

package EBox::Objects::Members;

use EBox::Types::IPRange;

sub new
{
    my ($class, $membersList) = @_;

    my $self =  $membersList;
    bless($self, $class);

    return $self;
}

# Method: addresses
#
#       Return the network addresses of all members
#
# Parameters:
#
#       mask - return also addresses' mask (named optional, default false)
#
# Returns:
#
#       list reference - containing strings  with ip mask, empty list if
#       there are no addresses in the object
#       In case mask is wanted the elements of the array would be  [ip, mask]
#
sub addresses
{
    my ($self, %params) = @_;
    my $mask = $params{mask};
    my $ranges = $params{ranges};

    my @ips = map {
        my $member = $_;
        my $type = $member->{type};
        if ($type eq 'ipaddr') {
            if ($mask) {
                my $ipAddr = $member->{'ipaddr'};
                $ipAddr =~ s:/.*$::g;
                [ $ipAddr =>  $member->{'mask'}]
            } else {
               $member->{'ipaddr'}
           }
        } elsif ($type eq 'iprange') {
            if (not defined $member->{addresses}) {
                my $beg = $member->{begin};
                my $end = $member->{end};
                $member->{addresses} = $ranges ? [ "$beg-$end" ] : EBox::Types::IPRange->addressesFromBeginToEnd($beg, $end);
            }
            if ($mask) {
                map {
                    [ $_ => 32 ]
               } @{ $member->{addresses} }
            } else {
                map {
                    "$_/32"
                } @{ $member->{addresses} }
            }
        } else {
            ()
        }
    } @{ $self };

    return \@ips;
}

# Method: iptablesSrcParams
#
#  returns a list with the iptables source parameters needed to match all
#  members
#  Each parameter is intended to be used in a different iptables command
#
#  Parameters:
#    useMac - if true the source MAc argument will be added when possible (default: false)
#
#  Return:
#   - list reference
sub iptablesSrcParams
{
    my ($self, $useMAC) = @_;
    my @params;
    foreach my $member (@{ $self }) {
        if ($member->{type} eq 'ipaddr') {
            my $arg =  ' --source ' .  $member->{ipaddr};
            if ($useMAC and $member->{macaddr}) {
                $arg .= ' -m mac --mac-source ' . $member->{macaddr};
            }
            push @params, $arg;
        } elsif ($member->{type} eq 'iprange') {
            push @params, ' -m iprange --src-range ' . $member->{begin} . '-' . $member->{end};
        }
    }

    return \@params;
}

# Method: iptablesDstParams
#
#  returns a list with the iptables destination parameters needed to match all
#  members
#  Each parameter is intended to be used in a different iptables command
#
#  Return:
#   - list reference
sub iptablesDstParams
{
    my ($self) = @_;
    my @params;
    foreach my $member (@{ $self }) {
        if ($member->{type} eq 'ipaddr') {
            push @params,  ' --destination ' .  $member->{ipaddr};
        } elsif ($member->{type} eq 'iprange') {
            push @params, ' -m iprange --dst-range ' . $member->{begin} . '-' . $member->{end};
        }
    }

    return \@params;
}

1;
