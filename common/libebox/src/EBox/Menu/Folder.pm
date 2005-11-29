# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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
	my $url = delete $opts{url};
	unless (defined($name) and ($name ne '')) {
		throw EBox::Exceptions::MissingArgument('name');
	}
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	$self->{name} = $name;
	$self->{url} = $url;
	return $self;
}

sub html
{
	my ($self, $current) = @_;
	my $text = $self->{text};
	my $url = $self->{url};
	my $html = '';
	my $show = 0;

	(scalar(@{$self->items()}) == 0) and return;

	if (defined($self->{style})) {
		$html .= "<li class='$self->{style}'>\n";
	} else {
		$html .= "<li>\n";
	}

	if (defined($url)) {
		if ($url eq $current) {
			$show = 1;
		}
		$html .= "<a title='$text' href='/ebox/$url' class='navarrow' ";
	} else {
		$html .= "<a title='$text' href='' class='navarrow' ";
		$html .= "onclick=\"showMenu('menu$self->{name}');return false;\"";
	} 

	$html .= " target='_parent'>$text</a>\n";

	$html .= "<ul class='submenu'>\n";


	foreach my $item (@{$self->items}) {
		if($item->{url} eq $current) {
			$show = 1;
		}
		$item->{style} = "menu$self->{name}";
		$html .= $item->html($current);
	}

	$html .= "</ul>\n";
	$html .= "</li>\n";

	if ($show) {
		$html .= "<script type='text/javascript'><!--\n" .
					"showMenu('menu$self->{name}');\n" .
					"//--></script>\n";
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
	if (defined($self->{url}) and (length($self->{url}) != 0)) {
		$node->{url} = $self->{url};
	}
	if (defined($self->{text}) and (length($self->{text}) != 0)) {
		$node->{text} = $self->{text};
	}
	push(@{$self->{items}}, @{$node->{items}});
}

1;
