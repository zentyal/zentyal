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

#	Migration between gconf data version from 3 to 4
#             in version 4 RulesTable is ordered (order created by the user)
#              so we must create a order for rules in version 3
#
package EBox::Migration;

use strict;
use warnings;

# eBox uses
use EBox;
use EBox::Global;

use base 'EBox::MigrationBase';


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
	my $userRulesDir  = "$iface/user_rules";
	
        my $keys_ref = $ts->array_from_dir("$userRulesDir/keys");

	my @order = map {
	    $_->{'_dir'}
	}
	sort {
	    # sort descending first by priority order (less is more), then
	    # guaranteed rate, then limited rate
	    my $ord;
	    $ord = $a->{priority} <=> $b->{priority};

	    if ($ord == 0) {
		$ord = $b->{guaranteed_rate} <=> $a->{guaranteed_rate};	

		if ($ord == 0) {
		    $ord = $b->{limited_rate} <=> $a->{limited_rate};	
		}
	    }

	    $ord;
	} @{ $keys_ref };


	$ts->set_list("$userRulesDir/order", 'string', \@order);

    }

}

EBox::init();
my $ts = EBox::Global->modInstance('trafficshaping');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ts,
				     'version' => 4
				    );
$migration->execute();
