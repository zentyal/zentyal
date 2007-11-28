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

#	Migration between gconf data version from 2 to 3
#
#       In version 1, the data version is as follows:
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
#       However, in version 2, it is required to add a boolean field
#       called 'enabled' which indicates if the rule must be applied
#       or not. Its default value is 'true'.
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
#       * enabled  - Boolean
#
package EBox::Migration;

use strict;
use warnings;

# eBox uses
use EBox;
use EBox::Global;

use base 'EBox::MigrationBase';

# Constants
use constant DEFAULT_ENABLED => 1;

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

    # Each interface directory
    my $ifaces = $ts->all_dirs_base('');
    foreach my $iface (@{$ifaces}) {
        my $keys_ref = $ts->array_from_dir("$iface/user_rules/keys");
        foreach my $rule_ref (@{$keys_ref}) {
            # This skips those directories already migrated
            next if ( exists $rule_ref->{enabled} );
            my $key = "$iface/user_rules/keys/" . $rule_ref->{_dir};
            EBox::info('Setting enabled rule to rule ' . $rule_ref->{_dir});
            $ts->set_bool( $key . '/enabled', 1);
        }
    }

}

EBox::init();
my $ts = EBox::Global->modInstance('trafficshaping');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ts,
				     'version' => 3
				    );
$migration->execute();
