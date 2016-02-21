# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Menu;

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Root;
use EBox::CGI::Run;

use Encode;
use TryCatch;
use Storable qw(store);


sub getKeywords
{
    my ($global, $keywords, $item) = @_;

    my $url  = $item->{url};
    my $title;
    my $modTitle;
    my $modName;
    my @words;
    if ($url) {
        my $model;
        try {
            $model = EBox::CGI::Run->modelFromUrl($item->{'url'});
        }  catch {};
        if ($model) {
            $title = $model->pageTitle();
            if (not $title) {
                $model->printableName();
                if (not $title) {
                    $title = $model->name();
                }
            }

            my $mod = $model->parentModule();
            $modName = $mod->name();
            $modTitle = $mod->printableName();
            push @words, map { lc $_ } @{ $model->keywords() };
        } else {
            $title = $item->{text};
            ($modName) = split('/', $url, 2);
            if ($modName) {
                $modName = lc $modName;
                if (not $global->modExists($modName)) {
                    $modName = '';
                }
            }
        }
    }

    if ($title) {
        if ($item->{'text'}) {
            my $text = lc $item->{'text'};
            push @words, split('\W+', $text);
        }

        my @linkElements;
        if ($modName) {
            my $modTitle =  $global->modInstance($modName)->printableName();
            if ($modTitle ne $title) {
                push @linkElements, {
                                           title => $modTitle,
                                    };
            }
        }

        push @linkElements, {
                              title => $title,
                              link  => $url,
                            };

        my $match = {
            module => $modName,
            linkElements => \@linkElements,
        };

        foreach my $word (@words) {
            if (not exists $keywords->{$word}) {
                $keywords->{$word} = {};
            }
            $keywords->{$word}->{$url} = $match;
        }
    }

    if ($item->items()) {
        for my $item (@{$item->items()}) {
            getKeywords($global, $keywords, $item);
        }
    }
}

sub cacheFile
{
    return EBox::Config::tmp . 'menucache';
}

sub regenCache
{
    my $keywords = {};

    my $root = new EBox::Menu::Root();

    my $global = EBox::Global->getInstance();
    foreach (@{$global->modNames}) {
        my $mod = $global->modInstance($_);
        $mod->menu($root);
    }

    getKeywords($global, $keywords, $root);
    # convert hashes to lists, since we already have unique elments
    foreach my $keywordValue (values %{$keywords}) {
        $keywordValue = [values %{ $keywordValue} ];
    }

    my $file = cacheFile();
    store($keywords, $file);
}

1;
