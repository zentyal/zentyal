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

# Class: EBox::Exceptions::NotImplemented
#
#       Internal exception raised when a method is not yet
#       implemented. It could be used in an Abstract class in order to
#       simulate its behaviour.

package EBox::Exceptions::NotImplemented;

use base 'EBox::Exceptions::Internal';

use Log::Log4perl;
use EBox::Gettext;

sub new
{
	my $class = shift;
	my $method = shift;
	my $caller = shift;

	local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
	local $Error::Debug = 1;

	$Log::Log4perl::caller_depth++;
	$self = $class->SUPER::new("Method '$method' not implemented in ".
				   "'$caller'");
	$Log::Log4perl::caller_depth--;

	bless ($self, $class);

	return $self;
}
1;
