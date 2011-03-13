#!/usr/bin/perl

# Copyright (C) 2011 eBox Technologies S.L.
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


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

# Private methods

# Return the newly-created objects based on fixedAddrModel indexed by
# interface
sub _migrateToObjects
{
    my ($self) = @_;

    my $dhcpMod = $self->{gconfmodule};
    my $objsMod = EBox::Global->modInstance('objects');

    $dhcpMod->models();
    foreach my $iface (keys %{$dhcpMod->{fixedAddrModel}}) {
        my $model = $dhcpMod->{fixedAddrModel}->{$iface};
        my $ids = $model->ids();
        next unless (@{$ids});

        # Create a new object
        my $set = 0;
        my $objName = "fixed-addresses-$iface";
        my $objs = $objsMod->objects();
        do {
            my $nMatches = grep { $_->{name} eq $objName } @{$objs};
            if ( $nMatches ) {
                $objName .= '-1';
            } else {
                $set = 1;
            }
        } while (not $set);

        my @members = ();
        foreach my $id (@{$ids}) {
            my $key  = $model->{directory} . "/$id";
            my $mac  = $dhcpMod->get_string("$key/mac");
            my $ip   = $dhcpMod->get_int("$key/ip");
            my $name = $dhcpMod->get_string("$key/name");
            push(@members, { name    => $name,
                             ipaddr  => "$ip/32",
                             macaddr => $mac });

            # Remove this row
            $model->removeRow($id);
        }
        EBox::info("Adding the new object $objName with " . scalar(@members) . ' members');
        my $newObjId = $objsMod->addObject1(name => $objName,
                                            members => \@members);

        EBox::info("Adding the new fixed address mapping for the $objName");
        $model->add(object      => $newObjId,
                    description => __('Migrated fixed addresses'));
    }

}


sub runGConf
{
    my ($self) = @_;

    $self->_migrateToObjects();

}

EBox::init();

my $dhcpMod = EBox::Global->modInstance('dhcp');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dhcpMod,
    'version' => 3
);
$migration->execute();
