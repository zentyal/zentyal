# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Dashboard::Value;

use strict;
use warnings;

use base 'EBox::Dashboard::Item';
use EBox::Gettext;

sub new  # (key, prettykey, value)
{
	my $class = shift;
	my $self = $class->SUPER::new();
	$self->{key} = shift;
	$self->{value} = shift;
	$self->{type} = 'value';
	bless($self, $class);
	return $self;
}

sub HTMLViewer()
{
    return '/dashboard/value.mas';
}

1;
