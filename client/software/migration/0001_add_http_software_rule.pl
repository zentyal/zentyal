#!/usr/bin/perl
#   Migration between gconf data version 0 to 1
# Copyright (C) 2008-2010 eBox Technologies S.L.
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

#
#   This migration script tries to add an HTTP service, and a rule to allow this
#   service to the Output rules

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub _addFirewallRule
{
    my $global = EBox::Global->getInstance();
    return unless ($global->modExists('services'));
    my $servMod = $global->modInstance('services');
    my $servId;
    my $name = __d('HTTP software');
    if (not $servMod->serviceExists(name => $name)) {
        my $description = __d('software service to update packages via apt');
        $servId = $servMod->addService( name => $name,
                protocol => 'tcp',
                sourcePort => 'any',
                destinationPort => '80',
                internal => 0,
                readOnly => 0,
                description => $description,
                translationDomain => 'ebox-services');

    } else {
        $servId = $servMod->serviceId($name);
    }

    return unless ($global->modExists('firewall'));
    my $fwMod = EBox::Global->modInstance('firewall');
    $fwMod->addOutputService( decision => 'accept',
            destination =>  {destination_any => 'any'},
            service => { inverse => 0, value => $servId},
            description => __d('rule to allow apt updates'));

    $servMod->saveConfig();
    $global->modRestarted('services');

    if (not $fwMod->configured()) {
        $fwMod->saveConfig();
        $global->modRestarted('firewall');
    } else {
        $fwMod->save();
    }
}

sub runGConf
{
    my ($self) = @_;

    $self->_addFirewallRule;
}

EBox::init();

my $softwareMod = EBox::Global->modInstance('software');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $softwareMod,
    'version' => 1
);
$migration->execute();
