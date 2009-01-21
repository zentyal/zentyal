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

package EBox::CGI::EBox::Lang;

use strict;
use warnings;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Menu;
use EBox::Config;
use EBox::Gettext;
use EBox::Sudo;
use POSIX qw(setlocale LC_ALL);

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	$self->{redirect} = "EBox/General";
	return $self;
}

sub _process
{
	my $self = shift;

	if (defined($self->param('setlang'))) {
		EBox::setLocale($self->param('lang'));
		POSIX::setlocale(LC_ALL, EBox::locale());
        EBox::Menu::regenMenuCache();
	}
}

1;
