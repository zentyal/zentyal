# Copyright (C) 2011 EBox Technologies S.L.
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

package EBox::RemoteServices::FirewallHelper;
use base 'EBox::FirewallHelper';

use constant STD_SSH_PORT => 22;
use constant LISTEN_ALL => '0.0.0.0';


sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    $self->{remoteSupport} = $params{remoteSupport};
    $self->{sshRedirect}       = $params{sshRedirect};
    $self->{vpnInterface}  = $params{vpnInterface};
    bless($self, $class);
    return $self;
}


# WARNING: the rules should be generated in a form which matches iptables-save
# output; otherwise route-up-support-access script will not work

sub prerouting
{
    my ($self) = @_;
    if (not $self->_mustRedirect()) {
        return [];
    }


    my $addr = $self->{sshRedirect}->{address};
    my $port = $self->{sshRedirect}->{port};

    my $iface = $self->{vpnInterface};

    my $cmd = qq{-t nat -i $iface } .
              qq{-p tcp -m tcp --dport } . STD_SSH_PORT . ' '; 
             
    if ($addr ne LISTEN_ALL) {
        $cmd .= qq{-j DNAT --to-destination $addr:$port}
    } else {
        $cmd .=   qq{-j REDIRECT --to-ports $port};
    }
    return [$cmd];
}


sub input
{
    my ($self) = @_;
    if (not $self->_mustRedirect()) {
        return [];
    }

    my $addr = $self->{sshRedirect}->{address};
    my $port = $self->{sshRedirect}->{port};
    my $iface = $self->{vpnInterface};

    my $cmd = '';
    if ($addr ne LISTEN_ALL) {
        $cmd .= qq{-d $addr/32 }
    }
    $cmd .= qq{-i $iface } .
              qq{-p tcp -m tcp --dport $port }; 
             

    $cmd .=   qq{-j ACCEPT};

    return [$cmd];
}

sub _mustRedirect
{
    my ($self) = @_;
    if (not $self->{remoteSupport}) {
        return 0;
    }
    if (not $self->{sshRedirect}) {
        return 0;
    }    
    if (not $self->{vpnInterface}) {
        return 0;
    }   

    return 1;
}


1;
