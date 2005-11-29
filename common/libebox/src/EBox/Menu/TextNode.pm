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

package EBox::Menu::TextNode;

use strict;
use warnings;

use base 'EBox::Menu::Node';
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

sub new 
{
	my $class = shift;
	my %opts = @_;
	my $text = delete $opts{text};
	unless (defined($text)) {
		throw EBox::Exceptions::MissingArgument('text');
	}
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	$self->{text} = $text;
	return $self;
}

sub _compare # (node)
{
	my ($self, $node) = @_;
	defined($node) or return undef;
	$node->isa('EBox::Menu::TextNode') or return undef;
	if (($node->{text} eq $self->{text}) and ($node->{url} eq $self->{url})) {
		return 1;
	}
	return undef;
}


1;
