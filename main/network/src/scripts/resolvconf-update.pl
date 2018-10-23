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
use TryCatch;
use EBox::Exceptions::Lock;

EBox::init();

my $operation = $ARGV[0];
my $interface = $ARGV[1];

exit 0 unless (defined $operation and length $operation);
exit 0 unless (defined $interface and length $interface);

# If the update if triggered for a user defined interface, we do not have
# to update the resolvers model. The interface for manually added resolvers is
# set to "zentyal.<row id>"
# Skip also systemd-resolved stuff
exit 0 if (($interface =~ m/zentyal\..+/) or ($interface =~ m/resolv/));

my $globalRO = EBox::Global->getInstance(1);
my $networkROModule = $globalRO->modInstance('network');
exit 0 unless ($networkROModule->configured() and $networkROModule->isEnabled());
if ($globalRO->modExists('dns')) {
    my $dnsModule = $globalRO->modInstance('dns');
    exit 0 if ($dnsModule->configured() and $dnsModule->isEnabled());
}

my $globalRW = EBox::Global->getInstance();
my $networkModule = $globalRW->modInstance('network');
my $model = $networkModule->model('DNSResolver');

my $alreadyChanged = $networkModule->changed();
my $changed = 0;

if ($operation eq '-d') {
    my @toDelete;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $modelInterface = $row->valueByName('interface');
        if ($modelInterface eq $interface) {
            push @toDelete, $id;
        }
    }
    foreach my $id (@toDelete) {
        $model->removeRow($id, 1);
        $changed = 1;
    }
}

if ($operation eq '-a') {
    my $ifaceConfig = $model->getInterfaceResolvconfConfig($interface);
    my @resolvers = @{$ifaceConfig->{resolvers}};
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $modelInterface = $row->valueByName('interface');
        if ($modelInterface eq $interface) {
            my $resolver = shift @resolvers;
            if ((defined $resolver) and length($resolver)) {
                my $el = $row->elementByName('nameserver');
                if ($el->value() ne $resolver) {
                    $el->setValue($resolver);
                    $row->setReadOnly(1);
                    $row->store();
                    $changed = 1;
                }
            }
        }
    }

    foreach my $r (@resolvers) {
        $model->addRow(nameserver => $r, interface => $interface, readOnly => 1);
        $changed = 1;
    }
}

if ($changed and not $alreadyChanged) {
    try {
        $networkModule->_lock();
        $networkModule->_saveConfig();
        $networkModule->_unlock();
    } catch (EBox::Exceptions::Lock $e) {
        # if locked, just mark as usnaved
    }
    $networkModule->setAsChanged(0);
}

exit 0;
