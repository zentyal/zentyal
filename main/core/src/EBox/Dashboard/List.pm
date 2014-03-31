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

package EBox::Dashboard::List;

use base 'EBox::Dashboard::Item';

use EBox::Gettext;

# Constructor: new
#
# Parameters:
#
#      title - String the list title
#      colTitles - Array ref the column titles
#      ids - Array ref the row identifiers
#      rows - Hash ref the rows to show indexed by id
#      none_text - String the text to show when the list is empty
#
sub new
{
	my $class = shift;
	my $self = $class->SUPER::new();
	$self->{title} = shift;
	$self->{colTitles} = shift;
	$self->{ids} = shift;
	$self->{rows} = shift;
	$self->{none_text} = shift;
	$self->{type} = 'list';
	bless($self, $class);
	return $self;
}

sub HTMLViewer()
{
    return '/dashboard/list.mas';
}

1;
