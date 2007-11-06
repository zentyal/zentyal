#!/usr/bin/perl

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

#	Migration between gconf data version 1 to 2
#
#       In version 1, the data version is as follows:
#          * service_protocol - String
#          * service_port - Int
#          * source_selected - String
#             -> One of these ones or none
#             o * source_ipaddr_ip - String
#               * source_ipaddr_mask - Int
#             o source_macaddr - String
#             o source_object - String
#          * destination_selected - String
#             -> One of these ones or none
#             o * destination_ipaddr_ip - String
#               * destination_ipaddr_mask - Int
#             o destination_object - String
#          * guaranteed_rate - Int
#          * limited_rate - Int
#
#       In version 2, the service is now stored as an enhanced version
#       on ebox-services module and any fields are added:
#
#       * service - String
#       * source_selected - String
#         -> One of these fields or any
#         o * source_ipaddr_ip - String
#           * source_ipaddr_mask - Int
#         o * source_macaddr - String
#         o * source_object - String
#       * destination_selected - String
#         -> One of these fields or any
#         o * destination_ipaddr_ip - String
#           * destination_ipaddr_mask - Int
#         o * destination_object - String
#       * guaranteed_rate - Int
#       * limited_rate - Int
#       * priority - Int
#
#       So, the already done protocol/port is added to the
#       ebox-services setting as name what is /etc/services is
#       described. Set the priority if there is not as 0.
#
package EBox::Migration;

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

use constant ANY_SOURCE       => 'source_any';
use constant ANY_DESTINATION  => 'destination_any';
use constant DEFAULT_PRIORITY => 0;

# Constructor: new
#
#      Overrides at <EBox::MigrationBase::new> method
#
# Returns:
#
#      A recently created <EBox::Migration> object
#
sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: runGConf
#
#       Overrides <EBox::MigrationBase::runGConf> method
#
sub runGConf
{
    my ($self) = @_;
    my $ts = $self->{'gconfmodule'};
    $self->{servMod} = EBox::Global->modInstance('services');

    # Each interface directory
    my $dirs_ref = $ts->array_from_dir('/ebox/modules/trafficshaping');
    foreach my $dir_ref (@{$dirs_ref}) {
        my $iface = $dir_ref->{_dir};
        my $keys_ref = $ts->array_from_dir("$iface/user_rules/keys");
        foreach my $rule_ref (@{$keys_ref}) {
            my $key = "$iface/user_rules/keys/" . $rule_ref->{_dir};
            my $protocol = $rule_ref->{service_protocol};
            my $port = $rule_ref->{service_port};
            # Erase old protocol/port keys
            $ts->unset($key . '/service_protocol');
            $ts->unset($key . '/service_port');
            $protocol = 'all' unless defined ( $protocol );
            my $servId = $self->_addService($protocol, $port);
            $ts->set_string( $key . '/service', $servId);
            # Set any field as selected when no value is set (ip,
            # object, whatever...)
            unless ( defined (  $rule_ref->{$rule_ref->{source_selected}} )
                   or ( $rule_ref->{source_selected} eq ANY_SOURCE )) {
                EBox::info("Setting a source as 'any' at a rule");
                $ts->set_string( $key . '/source_selected', ANY_SOURCE );
            }
            unless ( defined (  $rule_ref->{$rule_ref->{destination_selected}} )
                   or ( $rule_ref->{destination_selected} eq ANY_DESTINATION )) {
                EBox::info("Setting a destination as 'any' at a rule");
                $ts->set_string( $key . '/destination_selected', ANY_DESTINATION );
            }
            unless ( defined ( $rule_ref->{priority} )) {
                EBox::info('Setting a default priority to a rule');
                $ts->set_int( $key . '/priority', 0);
            }
        }
    }

}

# Method: _addService
#
#     Add a service if required to the ebox-services looking for the
#     name at '/etc/services' file or setting 'port/protocol' name if
#     not found
#
# Parameters:
#
#     protocol - String the protocol name. 'all' means any protocol
#
#     port - Int only some protocols (tcp and udp) requires a port to
#     work, then it is *optional*
#
# Returns:
#
#     String - the service identifier to set the traffic shaping rule
#
sub _addService
{

    my ($self, $protocol, $port) = @_;

    my $servMod = $self->{servMod};

    if ( $protocol eq 'all' ) {
        my $anyId = $servMod->serviceId('any');
        unless (defined($anyId)) {
            die 'there is no "any" service';
        }
        return $anyId;
    }
    my $servId;
    if ( $protocol eq 'icmp' or $protocol eq 'gre' ) {
        # These protocols does not have a port
        $servId = $servMod->serviceId($protocol);
        unless ( defined($servId)) {
            $servId = $servMod->addService(
                                           name => $protocol,
                                           description => uc ( $protocol ),
                                           protocol => $protocol,
                                           sourcePort => 'any',
                                           destinationPort => 'any',
                                           internal => 0
                                          );
            EBox::info("Adding service $protocol due to a traffic shaping rule");
        }
    } elsif ( $protocol eq 'udp' or $protocol eq 'tcp' ) {
        my $servName = getservbyport ( $port, $protocol);
        my $description = "$port/$protocol";
        unless ( defined ( $servName )) {
            $servName = $description;
        }
        $servId = $servMod->serviceId($servName);
        unless ( defined ( $servId )) {
            $servId = $servMod->addService(
                                           name => $servName,
                                           description => $description,
                                           protocol => $protocol,
                                           sourcePort => 'any',
                                           destinationPort => $port,
                                           internal => 0
                                          );
            EBox::info("Adding service $servName due to a traffic shaping rule");
        }
    } else {
        die "Wrong protocol name: $protocol";
    }

    return $servId;

}

EBox::init();
my $ts = EBox::Global->modInstance('trafficshaping');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ts,
				     'version' => 2
				    );
$migration->execute();
