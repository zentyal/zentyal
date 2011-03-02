#!/usr/bin/perl

# Copyright (C) 20011 eBox Technologies S.L.
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

#	Migration between gconf data version 7 to 8
#
#
#   Add a gconf value to the file lists which are missing one
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::Migration::Helpers;

sub runGConf
{
    my ($self) = @_;
    my $squid = $self->{gconfmodule};
    my @descriptionKeys;
    push @descriptionKeys, $squid->{redis}->_redis_call('keys',
      '/ebox/modules/squid/FilterGroup/keys/*/filterPolicy/FilterGroupDomainFilterFiles/keys/*/description');
    push @descriptionKeys, $squid->{redis}->_redis_call('keys',
'/ebox/modules/squid/FilterGroup/defaultFilterGroup/filterPolicy/DomainFilterFiles/keys/*/description');

    foreach my $descKey (@descriptionKeys) {
        my $fileListKey = $descKey;
        $fileListKey =~ s/description$/fileList_path/;
        if ($squid->get_string($fileListKey)) {
            next;
        }

        my $path =   '/etc/dansguardian/extralists';;
        my $isDefault = $fileListKey =~ m/defaultFilterGroup/;
        if (not $isDefault) {
            # get name to appedn to the dir
            my $nameKey = $fileListKey;
            $nameKey =~ s{/filterPolicy.*}{/name};

            my $profileName = $squid->get_string($nameKey);
            $path .= "/$profileName";
        }

        my $escapedDescription = $squid->get_string($descKey);
        $escapedDescription  =~ s{\s}{_}g;
        $path .= '/' . $escapedDescription;

        $squid->set_string($fileListKey, $path);
    }
}

EBox::init();

my $mod = EBox::Global->modInstance('squid');


my $migration = new EBox::Migration(
                                    'gconfmodule' => $mod,
                                    'version' => 8,
                                   );

$migration->execute();
