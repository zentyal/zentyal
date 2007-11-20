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

# Class: EBox::Exceptions::MissingArgument
#
#       Internal exception raised when a compulsory argument is
#       missing in a method call

package EBox::Exceptions::MissingArgument;

use base 'EBox::Exceptions::External';
use Log::Log4perl;
use EBox::Gettext;

# Constructor: new
#
#      An exception called when a mandatory argument is missing a
#      block call
#
# Parameters:
#
#      arg - the argument name
#
sub new 
{
	my $class = shift;
	my $arg = shift;

	local $Error::Depth = $Error::Depth + 1;
	local $Error::Debug = 1;

	$Log::Log4perl::caller_depth++;
	$self = $class->SUPER::new("Missing argument: $arg");
	$Log::Log4perl::caller_depth--;

	bless ($self, $class);

	return $self;
}
1;
