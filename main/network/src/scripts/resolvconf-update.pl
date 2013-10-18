#!/usr/bin/perl

# Copyright (C) 2013 Zentyal S.L.
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

# Documentation:
#
#   This is a hook script for resolvconf. It is triggered by resolvconf
#   updates and its objetive is update the DNSResolver model to reflect
#   the system changes.
#

use EBox;
use EBox::Global;

EBox::init();

my $operation = $ARGV[0];
my $interface = $ARGV[1];

exit 0 unless (defined $operation and length $operation);
exit 0 unless (defined $interface and length $interface);

# If the update if triggered for a user defined interface, we do not have
# to update the resolvers model. The interface for manually added resolvers is
# set to "zentyal.<row id>"
exit 0 if ($interface =~ m/zentyal\..+/);

my $networkModule = EBox::Global->modInstance('network');
exit 0 unless ($networkModule->configured() and $networkModule->isEnabled());

if (EBox::Global->modExists('dns')) {
    my $dnsModule = EBox::Global->modInstance('dns');
    exit 0 if ($dnsModule->configured() and $dnsModule->isEnabled());
}

my $model = $networkModule->model('DNSResolver');

if ($operation eq '-d') {
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $modelInterface = $row->valueByName('interface');
        if ($modelInterface eq $interface) {
            $row->setDisabled(1);
            $row->store();
        }
    }
}

if ($operation eq '-a') {
    my $ifaceConfig = $model->getInterfaceResolvconfConfig($interface);
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $modelInterface = $row->valueByName('interface');
        if ($modelInterface eq $interface) {
            my $resolver = shift $ifaceConfig->{resolvers};
            if (defined $resolver and length $resolver) {
                my $e = $row->elementByName('nameserver');
                $e->setValue($resolver);
                $row->setDisabled(0);
                $row->store();
            }
        }
    }
    foreach my $r (@{$ifaceConfig->{resolvers}}) {
        $model->addRow(nameserver => $r, interface => $interface);
    }
}

exit 0;
