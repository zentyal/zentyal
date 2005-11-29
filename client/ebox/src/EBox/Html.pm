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

package EBox::Html;

use strict;
use warnings;

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Menu::Root;

#
# Method: title 
#
#	Returns the html code for the title
#
# Returns:
#
#      	string - containg the html code for the title 
#
sub title
{
	my $save = __('Save changes');
	my $help = __('Help');
	my $logout = __('Logout');

	return qq%<div id="top"></div>
	<div id="header"><img src="/data/images/title.gif"></div>
	<div id="hmenu">
	<a id="m" href="/ebox/Finish">$save</a>
	<a id="mm" href="">$help</a>
	<a id="mmm" href="/ebox/Logout/Index">$logout</a>
	</div>
	%;
}

#
# Method: menu 
#
#	Returns the html code for the menu
#
# Returns:
#
#      	string - containg the html code for the menu
#
sub menu
{
	my $current = shift;

	my $global = EBox::Global->getInstance();

	my $root = new EBox::Menu::Root('current' => $current);
	my $domain = gettextdomain();
	foreach (@{$global->modNames}) {
		my $mod = $global->modInstance($_);
		settextdomain($mod->domain);
		$mod->menu($root);
	}
	settextdomain($domain);

	return $root->html;
}

#
# Method: footer 
#
#	Returns the html code for the footer page
#
# Returns:
#
#      	string - containg the html code for the footer page
#
sub footer($) # (module)
{
	my $module = shift;
	my $copy = __('Created by <a href="http://www.warp.es">' .
	'Warp Networks S.L.</a> in collaboration with ' .
	'<a href="http://www.dbs.es">DBS Servicios ' .
	'Informaticos S.L.</a>');
	return qq%<div id="footer">
	$copy</div>
	<script type="text/javascript" src="/data/js/help.js">//</script>
	<script type="text/javascript"><!--
	stripe('dataTable', '#ecf5da', '#ffffff');
	//--></script>
	</body>
	</html>
%;
}

#
# Method: header 
#
#	Returns the html code for the header page
#
# Returns:
#
#      	string - containg the html code for the header page
#
sub header # (title)
{
	my $title = shift;

	return qq%
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
		      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>eBox - $title</title>
<link href="/data/css/public.css" rel="stylesheet" type="text/css" />
<script type="text/javascript" src="/data/js/common.js">//</script>
</head>
<body>%
}

1;
