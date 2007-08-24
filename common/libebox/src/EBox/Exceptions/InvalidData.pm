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

# Class: EBox::Exceptions::InvalidData
#
#       External exception raised when a user  enters a value for a data
#       which is invalid. An advice to the user may be set.

package EBox::Exceptions::InvalidData;

use base 'EBox::Exceptions::External';
use EBox::Gettext;

sub new # (data=>string,  value=>string, advice => string)
{
	my $class = shift;
	my %opts = @_;

	my $data   = delete $opts{data};
	my $value  = delete $opts{value};
	my $advice = delete $opts{advice};

	my $old_domain = settextdomain('libebox');

	my $error = __x("Invalid value for {data}: {value}.", data => $data,
							 value => $value);
	if (defined $advice) {
	    $error .= "\n$advice";
	}

	settextdomain($old_domain);

	local $Error::Depth = $Error::Depth + 1;
	local $Error::Debug = 1;

	$Log::Log4perl::caller_depth++;
	$self = $class->SUPER::new($error, @_);
	$Log::Log4perl::caller_depth--;
	bless ($self, $class);
	return $self;
}
1;
