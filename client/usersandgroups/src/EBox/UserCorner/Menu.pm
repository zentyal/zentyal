package EBox::UserCorner::Menu;

use EBox::Config;
use EBox::Global;
use EBox::Menu;
use EBox::Menu::Root;
use EBox::Gettext;
use Storable qw(store);

sub menu
{
    my ($current) = @_;

    my $global = EBox::Global->getInstance();

    my $root = new EBox::Menu::Root('current' => $current);
    my $domain = gettextdomain();
    foreach my $mod
            (@{$global->modInstancesOfType('EBox::UserCorner::Provider')}) {
        settextdomain($mod->domain);
        $mod->userMenu($root);
    }
    settextdomain($domain);

    return $root;
}

sub cacheFile
{
    return EBox::Config::var . 'lib/ebox-usercorner/menucache';
}

sub regenCache
{
    my $keywords = {};

    my $root = menu();

    EBox::Menu::getKeywords($keywords, $root);

    my $file = cacheFile();
    store($keywords, $file);
}

1;
