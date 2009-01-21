# Copyright (C) 2009 eBox Technologies S.L.
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
use Error qw(:try);
use Storable qw(store);

sub _addWord
{
    my ($keywords, $word, $id) = @_;
    if(not defined($keywords->{$word})) {
        $keywords->{$word} = [];
    }
    if(!grep(/^$id$/, @{$keywords->{$word}})) {
        push(@{$keywords->{$word}}, $id);
    }
}

sub _getKeywords
{
    my ($keywords, $item) = @_;
    if(defined($item->{'text'})) {
        my $text = $item->{'text'};
        Encode::_utf8_on($text);
        $text = lc($text);
        my @words = split('\W+', $text);
        for my $word (@words) {
            _addWord($keywords, $word, $item->{id});
        }
    }
    if(defined($item->{'url'})) {
        try {
            my $classname = EBox::CGI::Run::classFromUrl($item->{'url'});
            my ($model, $action) = EBox::CGI::Run::lookupModel($classname);
            if($model) {
                my $words = $model->keywords();
                for my $word (@{$words}) {
                    _addWord($keywords, $word, $item->{id});
                }
            }
        } otherwise {
            EBox::debug('No model found for ' . $item->{'url'} . "\n");
        }
    }
    if($item->items()) {
        for my $i (@{$item->items()}) {
            _getKeywords($keywords, $i);
        }
    }
}

sub regenMenuCache
{
    my $keywords = {};

    my $root = new EBox::Menu::Root();
    my $domain = gettextdomain();

    my $global = EBox::Global->getInstance();
    foreach (@{$global->modNames}) {
        my $mod = $global->modInstance($_);
        settextdomain($mod->domain);
        $mod->menu($root);
    }

    _getKeywords($keywords, $root);

    my $file = EBox::Config::tmp . "menucache";
    store($keywords, $file);
}

1;
