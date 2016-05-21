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

# Class: EBox::Exceptions::DataInUse
#
#       External exception raised when there is a data in Zentyal which
#       it is about to be removed which it is being used by another
#       part of eBox.
#

package EBox::Exceptions::DataInUse;

use base 'EBox::Exceptions::External';

use Log::Log4perl;
use EBox::Gettext;

sub new #
{
	my $class = shift;
	$self = $class->SUPER::new(@_);
	return $self;
}
1;
