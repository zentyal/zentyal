# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::MenuCSS;

use strict;
use warnings;

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

sub domain
{
	return "ebox";
}

sub run
{
	my $self = shift;
	my $cgi = new CGI;
	my $module = $cgi->param('section');
	print $cgi->header('text/css');
	print "#nav .menu$module { display: block;}\n";
}

1;
