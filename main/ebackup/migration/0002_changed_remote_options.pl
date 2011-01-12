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

#
#   This migration script migrates RemoteSettings to the new version
#

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;



sub runGConf
{
    my ($self) = @_;
    $self->_fixFullFreq();
    $self->_fixIncrementalFreq();
    $self->_fixKeep();

}


sub _fixFullFreq
{
    my ($self) = @_;
    my $ebackup = $self->{gconfmodule};
    my $dir = 'RemoteSettings';

    my $key = "$dir/full";
    my $full = $ebackup->get_string($key);
    if (not defined $full) {
        # no set, nothing to migrate
        return;
    }

    my  $selectedValue = 'full_' . $full;
    my $selectedTypeKey = $dir . '/' . $selectedValue;
    if ($selectedValue eq 'full_weekly') {
        # sunday was the weekly day in the previous version
        $ebackup->set_string($selectedTypeKey, '0');
    } elsif ($selectedValue eq 'full_mothly') {
        # 1 was the backup day i nthe previous version
        $ebackup->set_string($selectedTypeKey, '1');
    }

    $ebackup->set_string("$dir/full_selected", $selectedValue);
    $ebackup->unset($key);
}


sub _fixIncrementalFreq
{
    my ($self) = @_;
    my $ebackup = $self->{gconfmodule};
    my $dir = 'RemoteSettings';

    my $key = "$dir/incremental";
   my $incremental = $ebackup->get_string($key);
    if (not defined $incremental) {
        # no set, nothing to migrate
        return;
    }

    my $fullFreq = $ebackup->get_string("$dir/full_selected");

    my  $selectedValue = 'incremental_' . $incremental;
    my $disabledSelectedType = 'incremental_disabled';
    if ($selectedValue eq 'incremental_weekly') {
        if (not $fullFreq eq 'full_monthly') {
            # incoherent conf disabling incremental backup
            $selectedValue = $disabledSelectedType;
            EBox::warn('Incoherent incremental frequency found, disabling it');
        }

        # sunday was the weekly day in the previous version
        $ebackup->set_string($dir . '/' . $selectedValue, '0');
    } elsif ($selectedValue eq 'incremental_daily') {
        if ($fullFreq eq 'full_daily') {
            # incoherent conf disabling incremental backup
            $selectedValue = $disabledSelectedType;
            EBox::warn('Incoherent incremental frequency found, disabling it');
        }

    }  elsif ($selectedValue eq 'incremental_monthly') {
           # incoherent conf disabling incremental backup
            $selectedValue = $disabledSelectedType;
            EBox::warn('Monthly incremental frequency deprecated, disabling it');

    }

    $ebackup->set_string("$dir/incremental_selected", $selectedValue);
    $ebackup->unset($key);
}

sub _fixKeep
{
    my ($self) = @_;
    my $ebackup = $self->{gconfmodule};
    my $dir = 'RemoteSettings';

    my $key = "$dir/full_copies_to_keep";
    my $selectedKey = $key . "_selected";
    my  $selectedValue = 'full_copies_to_keep_number';

    my $numberKeep = $ebackup->get_string($key);
    if (not defined $numberKeep) {
        my $selected = $ebackup->get_string($selectedKey);
        if (not defined $selected) {
            # put defaults
            $ebackup->set_string($selectedKey, $selectedValue);
            $ebackup->set_int("$dir/$selectedValue", 1);
            return;
        }
        # not set, nothing ot migrate
        return;
    }


    $ebackup->set_string($selectedKey, $selectedValue);
    $ebackup->set_int("$dir/$selectedValue", $numberKeep);
    $ebackup->unset($key);
}




EBox::init();

my $ebackup = EBox::Global->modInstance('ebackup');
my $migration = new EBox::Migration(
    'gconfmodule' => $ebackup,
    'version' => 2,
);
$migration->execute();

1;
