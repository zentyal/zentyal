# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::OpenVPN::Types::PortAndProtocol;

use strict;
use warnings;

use EBox::Validate qw( checkPort checkProtocol);
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;

use base 'EBox::Types::Service';

# Constructor: new
#
#     Create a type which includes the protocol and the port from
#     Internet as a service
#
# Returns:
#
#     a <EBox::Types::OpenVPN::PortAndProtocol> object
#
sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: protocols
#
#     Get the protocols available (Static method)
#
# Returns:
#
#     array ref - the protocols in a hash with the following elements
#              - value - the protocol name
#              - printableValue - the protocol printable name
#              - needPort - set true if it needs a port
#
sub protocols
{

    my ($self) = @_;

    my @protocols = (

        {
          value => 'tcp',
          printableValue => 'TCP',
          needPort => 1,
        },
        {
          value => 'udp',
          printableValue => 'UDP',
          needPort => 1,
        },

    );

    return \@protocols;
}

1;
