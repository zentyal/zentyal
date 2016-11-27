# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Network::CGI::Diag;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Exceptions::InvalidData;
use TryCatch;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Network Diagnostic Tools'),
                                  'template' => '/network/diag.mas',
                                  @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    $self->{title} = __('Network Diagnostic Tools');

    my $net = EBox::Global->modInstance('network');

    my @array = ();

    my $action = $self->param("action");

    my $objects = EBox::Global->modInstance('network');
    my @object_list;

    for my $object (@{$objects->objects()}) {
        my $there_is_mac = 0;
        for my $member (@{$objects->objectMembers($object->{id})}) {
            $there_is_mac = $there_is_mac || defined $member->{macaddr};
        }
        if ($there_is_mac) {
            push(@object_list, $object);
        }
    }

    if(defined($action)){
        if($action eq "ping"){
            $self->_requireParam("ip", __("Host"));
            my $ip = $self->param("ip");
            my $output = $net->ping($ip);
            push(@array, 'action' => 'ping');
            push(@array, 'target' => $ip);
            push(@array, 'output' => $output);
        }elsif($action eq "traceroute"){
            $self->_requireParam("ip", __("Host"));
            my $ip = $self->param("ip");
            my $output = $net->traceroute($ip);
            push(@array, 'action' => 'traceroute');
            push(@array, 'target' => $ip);
            push(@array, 'output' => $output);
        }elsif($action eq "dns"){
            $self->_requireParam("host", __("host name"));
            my $host = $self->param("host");
            my $output = $net->resolv($host);
            push(@array, 'action' => 'dns');
            push(@array, 'target' => $host);
            push(@array, 'output' => $output);
        } elsif ($action eq "wakeonlan") {
            my $id = $self->param("object_id");
            my $broadcast = $self->param('broadcast');
            unless  ("$broadcast\." =~ m/^(([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){4}$/){
                throw EBox::Exceptions::InvalidData
                    ('data' => __('Broadcast address'), 'value' => $broadcast);
            }

            if ( $id eq 'other' || $id eq '' ) {
                try {
                    $self->_requireParam("mac", __("MAC address"));
                } catch ($e) {
                    push(@array, 'objects' => \@object_list);
                    $self->{params} = \@array;

                    $e->throw();
                }
                my $mac = $self->param("mac");
                EBox::Validate::checkMAC($mac, __("MAC address"));

                my $output = $net->wakeonlan($broadcast, $mac);
                push(@array, 'action' => 'wakeonlan');
                push(@array, 'target' => $mac);
                push(@array, 'output' => $output);
            } else {
                my $objects = EBox::Global->modInstance('network');
                my @macs;
                for my $member (@{$objects->objectMembers($id)}) {
                    push(@macs, $member->{macaddr});
                }

                my $output = $net->wakeonlan($broadcast, @macs);
                push(@array, 'action' => 'wakeonlan');
                push(@array, 'target' => $id);
                push(@array, 'output' => $output);
            }
        }
    }
    push(@array, 'objects' => \@object_list);
    $self->{params} = \@array;
}

1;
