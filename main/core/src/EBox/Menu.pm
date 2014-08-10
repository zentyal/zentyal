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
use TryCatch::Lite;
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
        try {
            my $model = EBox::CGI::Run->modelFromUrl($item->{'url'});
            if ($model) {
                $title = $model->printableModelName();
                if (not $title) {
                    $title = $model->tableName();
                }
                my $mod = $model->parentModule();
                $modName = $mod->name();
                $modTitle = $mod->printableName();
                push @words, map { lc $_ } @{ $model->keywords() };
                push @word, split('\W+', lc $model->printableName());
            }
        } catch {
            EBox::debug('No model found for ' . $item->{'url'} . "\n");
        }        
    }

    if ($title) {
        if ($item->{'text'}) {
            my $text = lc $item->{'text'};
            push @words, split('\W+', $text);
        }
    
        my $linkElements = [
            {
                title => $global->modInstance($modName)->printableName(),
            },
            {
                title => $title,
                link  => $url,
            }
        ];

        my $match = {
            module => $modName,
            linkElements => $linkElements,
        };

        foreach my $word (@words) {
            if (not exists $keywords->{$word}) {
                $keywords->{$word} = {};
            }
            $keywords->{$word}->{$url} = $match;
        }
    }

    if ($item->items()) {
        for my $i (@{$item->items()}) {
            getKeywords($global, $keywords, $i);
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
    # normalize keywords
    foreach my $keywordValue (values %{$keywords}) {
        $keywordValue = [values %{ $keywordValue} ];
    }

    my $file = cacheFile();
    store($keywords, $file);
}

1;
