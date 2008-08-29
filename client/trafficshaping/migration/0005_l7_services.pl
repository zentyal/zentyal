#!/usr/bin/perl

# Copyright (C) 2008 eBox technologies S.L
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

#	Migration between gconf data version 4 to 5
#
#	In version 4, there was just one kind of service, port based service
#       * service - String
#
#   In version 5, l7 services are introduced. So we have to migrate from
#   a select type to a union type.
#
#       * service_selected - string
#             -> One of these ones
#               * service_port - String
#               * service_l7Protocol - String
#               * service_l7Group -String
#
#   So let's see an example of this migration:
#
#       Version 4
#           * service = serv1234
#        Verison 5
#           * service_selected = service_port
#           * service_port = serv1234
#           * unset service
#
package EBox::Migration;

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

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
        my $keys_ref = $ts->array_from_dir("$iface/user_rules/keys");
        foreach my $rule_ref (@{$keys_ref}) {
            my $key = "$iface/user_rules/keys/" . $rule_ref->{_dir};
            my $service = $ts->get_string( $key . '/service');
            next unless (defined($service));
            $ts->set_string( $key . '/service_selected', 'service_port');
            $ts->set_string( $key . '/service_port', $service);
            $ts->unset($key . '/service');
        }
    }

}

EBox::init();

my $ts = EBox::Global->modInstance('trafficshaping');
my $migration = new EBox::Migration( 
        'gconfmodule' => $ts,
        'version' => 5
        );
$migration->execute();
