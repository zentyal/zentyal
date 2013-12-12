# Copyright (C) 2011-2012 Zentyal S.L.
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

# Class: EBox::RemoteServices::AdminPort
#
#     This class is intended as the client side to notify on server changes
#

package EBox::RemoteServices::AdminPort;
use base 'EBox::RemoteServices::Cred';

use strict;
use warnings;

use EBox;
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::AdminPort> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: setAdminPort
#
#     Set the TCP port where the Zentyal server UI is listening to
#
# Parameters:
#
#     port - Int the new TCP port
#
# Returns:
#
#     true - if everything goes as it should
#
sub setAdminPort
{
    my ($self, $port) = @_;

    my $uuid = $self->{cred}->{uuid};
    my $response = $self->RESTClient()->PUT("/v1/servers/$uuid/adminport/",
                                            query => { port => $port },
                                            retry => 1);

    return ($response->{result}->is_success());
}

1;
