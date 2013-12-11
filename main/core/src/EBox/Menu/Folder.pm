# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::Menu::Folder;

use base 'EBox::Menu::TextNode';

use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $name = delete $opts{name};
    unless (defined($name) and ($name ne '')) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $self = $class->SUPER::new(@_);
    $self->{name} = $name;
    $self->{url}  = delete $opts{url};

    bless($self, $class);
    return $self;
}

my $foldersToHide = undef;

sub html
{
    my ($self, $currentFolder, $currentUrl) = @_;
    defined $currentFolder or $currentFolder = '';

    unless (defined $foldersToHide) {
        $foldersToHide = {
            map { $_ => 1 } split (/,/, EBox::Config::configkey('menu_folders_to_hide'))
        };
    }

    my $name = $self->{name};
    my $text = $self->{text};
    if ($foldersToHide->{$name} or (scalar(@{$self->items()}) == 0)) {
        return '';
    }

    my $menuClass = "menu$name";
    my $id = $self->{id};
    my $liClass = $menuClass;
    if ($self->{style}) {
        $liClass .= " $self->{style}";
    }
    my $html = "<li id=\"$id\" class=\"$liClass\">\n";

    my $isCurrentFolder = ($name eq $currentFolder);
    my $aClass = '';
    if ($self->{icon}) {
        $aClass = "icon-$self->{icon}";
    }
    $aClass .= $isCurrentFolder ? ' despleg' : ' navarrow';

    my $url = $self->{url};
    if (defined $url) {
        $html .= "<a title='$text' href='/$url' class='$aClass' ";
    } else {
        $html .= "<a title='$text' href='' class='$aClass' ";
        $html .= "onclick=\"Zentyal.LeftMenu.showMenu('menu$name', this);return false;\"";
    }

    $html .= " target='_parent'>$text</a>\n";

    $html .= "<ul class='submenu'>\n";

    my @sorted = sort { $a->{order} <=> $b->{order} } @{$self->items()};
    foreach my $item (@sorted) {
        $item->{style} = $menuClass;
        $html .= $item->html($isCurrentFolder, $currentUrl);
    }

    $html .= "</ul>\n";
    $html .= "</li>\n";

    if ($isCurrentFolder) {
      # JS call to set the correct variables
        $html .= <<"END_JS"
<script type="text/javascript">
    Zentyal.LeftMenu.showMenu('$menuClass', \$('#$id'));
</script>
END_JS
    }

    return $html;
}

sub _compare # (node)
{
    my ($self, $node) = @_;
    defined($node) or return undef;
    $node->isa('EBox::Menu::Folder') or return undef;
    if ($node->{name} eq $self->{name}) {
        return 1;
    }
    return undef;
}

sub _merge # (node)
{
    my ($self, $node) = @_;

    if ($self->{url}) {
        $node->{url} = $self->{url};
    }
    if ($self->{text}) {
        $node->{text} = $self->{text};
    }
    foreach my $item (@{$node->{items}}) {
        $self->add($item);
    }
}

1;
