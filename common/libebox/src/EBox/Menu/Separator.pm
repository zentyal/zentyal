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

package EBox::Menu::Separator;

use strict;
use warnings;

use base 'EBox::Menu::TextNode';
use EBox::Exceptions::Internal;
use EBox::Gettext;

sub new
{
	my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return $self;
}

sub html
{
	my ($self, $current) = @_;
	my $text = $self->{text};
	my $html = '';
	my $show = 0;

	if (defined($self->{style})) {
		$html .= "<li id='" . $self->{id} . "' class='$self->{style}'>\n";
	} else {
		$html .= "<li id='" . $self->{id} . "'>\n";
	}

    $html .= "<div class='separator'>$text</div>\n";

	$html .= "</li>\n";

	return $html;
}

sub _compare # (node)
{
	my ($self, $node) = @_;
	defined($node) or return undef;
	$node->isa('EBox::Menu::Separator') or return undef;
	if ($node->{text} eq $self->{text}) {
		return 1;
	}
	return undef;
}

sub _merge # (node)
{
	my ($self, $node) = @_;

	if (defined($self->{text}) and (length($self->{text}) != 0)) {
		$node->{text} = $self->{text};
	}
}

1;
