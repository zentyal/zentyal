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

package EBox::Exceptions::DeprecatedMethod;

use base 'EBox::Exceptions::Internal';
use Log::Log4perl;
use EBox::Gettext;

sub new 
{
	my $class = shift;

	local $Error::Depth = $Error::Depth + 3;
	local $Error::Debug = 1;

	$Log::Log4perl::caller_depth += 3;
	$self = $class->SUPER::new("Call to deprecated method.");
	$Log::Log4perl::caller_depth -= 3;

	bless ($self, $class);

	return $self;
}
1;
