# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Menu::Folder;

use strict;
use warnings;

use base 'EBox::Menu::TextNode';
use EBox::Exceptions::Internal;
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
        bless($self, $class);
	$self->{name} = $name;
        return $self;
}

sub html
{
	my $self = shift;
	my $text = $self->{text};
	my $html = '';

	(scalar(@{$self->items()}) == 0) and return;

	if (defined($self->{style})) {
		$html .= "<li class='$self->{style}'>\n";
	} else {
		$html .= "<li>\n";
	}

	$html .= "<a title='$text' href='' class='navarrow' ".
		    "onclick=\"showMenu('menu$self->{name}');return false;\"".
		    "target='_parent'>$text</a>\n";

	$html .= "<ul class='submenu'>\n";

	foreach my $item (@{$self->items}) {
		$item->{style} = "menu$self->{name}";
		$html .= $item->html;
	}

	$html .= "</ul>\n";
	$html .= "</li>\n";

	return $html;
}

1;
