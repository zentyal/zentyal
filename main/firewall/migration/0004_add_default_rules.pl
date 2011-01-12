#!/usr/bin/perl

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

#   Migration between gconf data version 3 to 4
#
#
#   This migration script just tries to add a rule to allow outcoming
#   connections by Zentyal and also connections from internal to external.
#
#   There's no migration from previous data as we only need to add a rule.
#
#   We only add the rule if the user has not added any output rule.
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);




sub runGConf
{
    my ($self) = @_;

    $self->_allowOutput();
    $self->_allowInternal();

}

sub _allowOutput
{
    my ($self) = @_;

    my $fw =
        EBox::Model::ModelManager::instance()->model('EBoxOutputRuleTable');
    my $service = EBox::Model::ModelManager::instance()->model('ServiceTable');
    my $anyRow = $service->findValue(name => 'any');
    unless (defined($anyRow)) {
        EBox::warn('There must be something broken as I could not find "any" service');
        return;
    }
    $fw->add(
            decision => 'accept',
            destination => { destination_any => undef },
            description => '',
            service => $anyRow->id()
            );
}

sub _allowInternal
{
    my ($self) = @_;

    my $fw =
        EBox::Model::ModelManager::instance()->model('ToInternetRuleTable');
    my $service = EBox::Model::ModelManager::instance()->model('ServiceTable');
    my $anyRow = $service->findValue(name => 'any');
    unless (defined($anyRow)) {
        EBox::warn('There must be something broken as I could not find "any" service');
        return;
    }
    $fw->add(
            decision => 'accept',
            source => { source_any => undef },
            destination => { destination_any => undef },
            description => '',
            service => $anyRow->id()
            );

}

EBox::init();

my $fwMod = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration(
				    'gconfmodule' => $fwMod,
				    'version' => 4,
				   );

$migration->execute();
