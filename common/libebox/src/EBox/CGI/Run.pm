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

package EBox::CGI::Run;

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::CGI::Base;
use CGI;

sub run # (url)
{
	shift;
	my $script = shift;	
	my $classname = "EBox::CGI::";

	defined($script) or exit;

	$script =~ s/\?.*//g;
	$script =~ s/[\\"']//g;
	$script =~ s/\//::/g;
	$script =~ s/^:://;

	$classname .= $script;

	$classname =~ s/::::/::/g;
	$classname =~ s/::$//;

	if ($classname eq 'EBox::CGI') {
		$classname .= '::Summary::Index';
	}

	settextdomain('ebox');

	my $cgi;
	eval "use $classname"; 
	if ($@) {
		my $log = EBox::logger;
		$log->error("Unable to import cgi: $classname");
		my $error_cgi = EBox::Config::configkey("default_error_cgi");
		eval "use $error_cgi"; 
		$cgi = new $error_cgi(
			error => __d("The page could not be found",'libebox'));
	} else {
		$cgi = new $classname;
	}

	$cgi->run;
}

1;
