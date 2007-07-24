#!/usr/bin/perl

# Copyright (C) 2006 Warp Networks S.L.
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

#	Migration between gconf data version 0 to 1
#
#	In version 0, these attributes are stored per rule
#          * protocol - String
#          * port     - Int
#          * guaranteed_rate - Int
#          * limited_rate - Int
#
#       In version 1, an enhancement version is done
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
package EBox::Migration;

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

use constant DEFAULT_SOURCE      => 'source_ipaddr';
use constant DEFAULT_DESTINATION => 'destination_ipaddr';

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
	my $self = shift;
	my $ts = $self->{'gconfmodule'};

	# Each interface directory
	my $dirs_ref = $ts->array_from_dir('/ebox/modules/trafficshaping');
	foreach my $dir_ref (@{$dirs_ref}) {
	  my $iface = $dir_ref->{_dir};
	  my $keys_ref = $ts->array_from_dir("$iface/user_rules/keys");
	  foreach my $rule_ref (@{$keys_ref}) {
	    my $key = "$iface/user_rules/keys/" . $rule_ref->{_dir};
	    my $protocol = $rule_ref->{protocol};
	    my $port = $rule_ref->{port};
	    # Erase old protocol/port keys
	    $ts->unset($key . '/protocol');
	    $ts->unset($key . '/port');
	    # Set the old values with the new key
	    $ts->set_string($key . '/service_protocol', $protocol);
	    $ts->set_int($key . '/service_port', $port);
	    # Set default destination and source
	    $ts->set_string($key . '/source_selected', DEFAULT_SOURCE);
	    $ts->set_string($key . '/destination_selected', DEFAULT_DESTINATION);
	  }
	}

}

EBox::init();
my $ts = EBox::Global->modInstance('trafficshaping');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $ts,
				     'version' => 1
				    );
$migration->execute();
