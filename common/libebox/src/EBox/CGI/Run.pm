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
use EBox::FirstTime;
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
	

	if (EBox::FirstTime::isFirstTime()) {
              $classname = firstTimeClassName($classname);
	}
	elsif ($classname eq 'EBox::CGI') {
		$classname .= '::Summary::Index';
	}

	settextdomain('ebox');

	my $cgi;
	eval "use $classname"; 
	if ($@) {
		my $log = EBox::logger;
		$log->error("Unable to import cgi: $classname Eval error: $@");

		my $error_cgi = 'EBox::CGI::EBox::PageNotFound';
		eval "use $error_cgi"; 
		$cgi = new $error_cgi;
	} 
        else {
		$cgi = new $classname;
	}

	$cgi->run;
}


sub firstTimeClassName
{
    my ($classname) = @_;

    ### login and logout classes had priority over first time index
    return $classname if $classname =~ m{::Login::};
    return $classname if $classname =~ m{::Logout::};
    ### other first time classes must not be replaced by the firsttime index
    return $classname if $classname =~ m{::FirstTime::};
    ### change to firstime index...
    return 'EBox::CGI::FirstTime::Index' ; 
}

1;
