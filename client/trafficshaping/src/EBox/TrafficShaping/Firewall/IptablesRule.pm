# Copyright (C) 2008 eBox technologies S.L.
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

# Class: EBox::TrafficShaping::Firewall::IptablesRule
#
#   This class extends <EBox::Firewall::IptablesRule> to add
#   some stuff which is needed by traffic shaping:
#
#   - When setting a protocol based service, if we are adding rules
#     to an internal interface (i.e: we are doing ingress shapping)
#     we need to reverse the service configuration: source port is destination
#     port and vice versa.
#
#   - Setting L7 services
#
package EBox::TrafficShaping::Firewall::IptablesRule;

use warnings;
use strict;

use EBox::Model::ModelManager;
use EBox::Exceptions::MissingArgument;

use Perl6::Junction qw( any );

use base 'EBox::Firewall::IptablesRule';

sub new 
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_); 
    bless($self, $class);
    return $self;

}

# Method: setReverseService
#
#   This method reverse port service:
#       
#       destination -> source, source -> destination
#
#   It's meant to be used for ingress rules by the traffic shaping module
#
# Parameters:
#
#   (POSITIONAL)
#
#   service - a service id from <EBox::Service::Model::ServiceTable>
#   inverseMatch - inverse match  
sub setReverseService
{
    my ($self, $service, $inverseMatch) = @_;

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument("service");
    }

    my $serviceConf = $self->{'services'}->serviceConfiguration($service);
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service',
                'value' => $service);
    }

    my $inverse = '';
    if ($inverseMatch) {
        $inverse = ' ! ';
    }

    my $iptables;
    foreach my $ser (@{$serviceConf}) {
        $iptables = "";
        # Reverse source and destination
        my $srcPort = $ser->{'destination'};
        my $dstPort = $ser->{'source'};
        my $protocol = $ser->{'protocol'};
        my $invProto = '';
        if ($inverseMatch and $srcPort eq 'any' and  $dstPort eq 'any') {
            $invProto = ' ! ';
        }

        if ($protocol eq any ('tcp', 'udp', 'tcp/udp')) {
        
            if ($srcPort ne 'any') {
                $iptables .= " --source-port $inverse $srcPort ";
            }

   
            if ($dstPort ne 'any') {
                $iptables .= " --destination-port $inverse $dstPort ";
            }

            if ($protocol eq 'tcp/udp') {
                push (@{$self->{'service'}}, " -p $invProto udp " . $iptables);
                push (@{$self->{'service'}}, " -p $invProto tcp " . $iptables);    
            } else {
                push (@{$self->{'service'}}, " -p $invProto $protocol " 
                                             . $iptables);    
            }

        } elsif ($protocol eq any ('gre', 'icmp')) {
            $iptables = " -p $invProto $protocol";
            push (@{$self->{'service'}}, $iptables);
        } elsif ($protocol eq 'any') {
            push (@{$self->{'service'}}, '');
        }
    }
}

# Method: setL7Service
#
#   Set service for the rule
#
# Parameters:
#
#   (POSITIONAL)
#
#   l7service name
sub setL7Service
{
    my ($self, $service, $inverseMatch) = @_;

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument("service");
    }

    my $inverse = '';
    if ($inverseMatch) {
        $inverse = ' ! ';
    }

  push (@{$self->{'service'}}, " -m layer7 --l7proto $inverse $service");
}

# Method: setL7GroupedService
#
#   Set a grouped service
#
# Parameters:
#
#   (POSITIONAL)
#   
#   l7 grouped service id
#   
sub setL7GroupedService
{
    my ($self, $service, $inverseMatch) = @_;

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument("service");
    }

    my $inverse = '';
    if ($inverseMatch) {
        $inverse = ' ! ';
    }

    my $l7mod = EBox::Global->modInstance('l7-protocols')->model('Groups');
    my $row = $l7mod->row($service);
    unless (defined($row)) {
        throw EBox::Exceptions::External("group $service does not exist");
    }

    my @protocols;
    for my $subRow (@{$row->subModel('protocols')->rows()}) {
        my $ser =  $subRow->valueByName('protocol');
        push (@{$self->{'service'}}, " -m layer7 --l7proto $inverse $ser");
    }

}


1;
