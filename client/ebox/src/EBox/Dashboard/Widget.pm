# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::Dashboard::Widget;

use strict;
use warnings;

use EBox::Gettext;

sub new # (title?)
{
	my ($class, $title, $module, $name) = @_;
	my $self = {};
	$self->{title} = $title;
	$self->{module} = $module;
	$self->{name} = $name;
	bless($self, $class);
	return $self;
}

sub add # (section)
{
    my ($self,$section) = @_;
    $section->isa('EBox::Dashboard::Section') or
        throw EBox::Exceptions::Internal(
        "Tried to add a non-item to an EBox::Dashboard::Section");

    push(@{$self->sections()}, $section);
}

sub sections
{
    my ($self) = @_;
    unless (defined($self->{sections})) {
        my @array = ();
        $self->{sections} = \@array;
    }
    return $self->{sections};
}

1;
