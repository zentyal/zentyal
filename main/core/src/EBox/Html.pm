# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Html;

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Menu::Root;

use HTML::Mason;

# Method: title
#
#   Returns the html code for the title
#
# Returns:
#
#   string - containg the html code for the title
#
sub title
{
    my $save = __('Save changes');
    my $logout = __('Logout');

    my $global = EBox::Global->getInstance();
    my $finishClass;
    if ($global->unsaved()) {
        $finishClass = "changed";
    } else {
        $finishClass = "notchanged";
    }

    # Display control panel button only if the eBox is subscribed
    my $remoteServicesURL = '';
    if ($global->modExists('remoteservices')) {
        my $remoteServicesMod = $global->modInstance('remoteservices');
        if ($remoteServicesMod->eBoxSubscribed()) {
            unless (EBox::Config::configkey('hide_cloud_link')) {
                $remoteServicesURL = $remoteServicesMod->controlPanelURL();
            }
        }
    }
    my $image_title = $global->theme()->{'image_title'};

    my $html = makeHtml('headTitle.mas',
                        save => $save,
                        logout => $logout,
                        finishClass => $finishClass,
                        remoteServicesURL => $remoteServicesURL,
                        image_title => $image_title,
                        version => _htmlVersion());
    return $html;
}

# Method: titleNoAction
#
#   Returns the html code for the title without action buttons
#
# Returns:
#
#   string - containg the html code for the title
#
sub titleNoAction
{
    my $global = EBox::Global->getInstance();
    my $image_title = $global->theme()->{'image_title'};

    my $html = makeHtml('headTitle.mas',
                        image_title => $image_title,
                        version => _htmlVersion());
    return $html;
}

# Method: menu
#
#   Returns the html code for the menu
#
# Returns:
#
#   string - containg the html code for the menu
#
sub menu
{
    my ($currentMenu, $currentUrl) = @_;

    my $global = EBox::Global->getInstance();

    my $root = new EBox::Menu::Root('current' => $currentMenu, 'currentUrl' => $currentUrl);
    foreach (@{$global->modNames}) {
        my $mod = $global->modInstance($_);
        $mod->menu($root);
    }

    return EBox::Html::makeHtml($root->htmlParams());
}

# Method: footer
#
#   Returns the html code for the footer page
#
# Returns:
#
#   string - containg the html code for the footer page
#
sub footer
{
    return makeHtml('footer.mas');
}

# Method: header
#
#   Returns the html code for the header page
#
# Returns:
#
#   string - containg the html code for the header page
#
sub header
{
    my ($title, $folder) = @_;

    my $serverName = __('Zentyal');
    my $global = EBox::Global->getInstance();
    if ( $global->modExists('remoteservices') ) {
        my $remoteServicesMod = $global->modInstance('remoteservices');
        if ( $remoteServicesMod->eBoxSubscribed() ) {
            $serverName = $remoteServicesMod->eBoxCommonName();
        }
    }

    if ($title) {
        $title = "$serverName - $title";
    } else {
        $title = $serverName;
    }

    my $favicon = $global->theme()->{'favicon'};
    my $html = makeHtml('header.mas', title => $title, favicon => $favicon, folder => $folder);
    return $html;

}

my $output;
my $interp;
sub makeHtml
{
    my ($filename, @params) = @_;

    my $filePath = EBox::Config::templates . "/$filename";

    $output = '';
    if (not $interp) {
        $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::templates, out_method => \$output,);
    }

    my $comp = $interp->make_component(comp_file => $filePath);
    $interp->exec($comp, @params);
    return $output;
}

sub _htmlVersion
{
    my $version = EBox::Config::version();

#    unless (EBox::Global->communityEdition()) {
#        $version .= ' <em>Service Pack 1</em>';
#    }

    return $version;
}

1;
