# Copyright (C) 2014 Zentyal S.L.
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


#
package EBox::Search;

use EBox::Config::Redis;
use EBox::Global;
use EBox::Menu;
use TryCatch::Lite;
use Storable qw(retrieve);

# Assumpiton: only search in conf, RO must be ignored but later we could search
# in state or in non-redis places
sub search
{
    my ($searchString) = @_;
    my @matches;
    my $global = EBox::Global->getInstance();
    my @modInstances = @{ $global->modInstances() };

    @matches = @{ _menuMatches($searchString, \@modInstances)  };
    foreach my $mod (@modInstances) {
        push @matches, @{ $mod->searchContents($searchString)};
    }

    return \@matches;
}

sub _menuMatches
{
    my ($searchString, $modInstances_r) = @_;
    my @matches;
    $searchString = lc $searchString;

    my $file = EBox::Menu->cacheFile();
    unless (-f $file) {
        EBox::Menu->regenCache();
    }
    my $keywords = retrieve($file);
    my @searchWords = split(/\W+/, $searchString);
    foreach my $word (@searchWords) {
        if (exists $keywords->{$word}) {
            push @matches, @{ $keywords->{$word} };
        }
    }

    return \@matches;
}

1;
