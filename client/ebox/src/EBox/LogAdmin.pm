# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::LogAdmin;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::DBEngineFactory;
use Apache;

BEGIN {
	use Exporter ();
	our($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS = (all => [qw{ logAdminNow logAdminDeferred
	               commitPending rollbackPending pendingActions } ], );
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}

# Method: logAdmin
#
#	This function logs an administrative action
#
#
sub _logAdmin
{
	my ($module, $message, $committed) = @_;
	
	my $req = Apache->request();
	my $client = $req->get_remote_host();

	my $dbengine = EBox::DBEngineFactory::DBEngine();

	my $time = localtime();
	my $data = { 'timestamp' => $time, 'clientaddress' => $client,
		'module' => $module, 'message' => $message, 'committed' => $committed };
	$dbengine->insert('admin', $data);
}

# Method: logAdminDeferred
sub logAdminDeferred
{
	my ($module, $message) = @_;
	_logAdmin($module, $message, 'false');
}

# Method: logAdminNow
sub logAdminNow
{
	my ($module, $message) = @_;
	_logAdmin($module, $message, 'true');
}

# Method: rollbackPending
sub commitPending
{
	my $dbengine = EBox::DBEngineFactory::DBEngine();
	$dbengine->query("UPDATE admin SET committed = 'true' WHERE committed = 'f'");
}

# Method: rollbackPending
sub rollbackPending
{
	my $dbengine = EBox::DBEngineFactory::DBEngine();
	$dbengine->query("DELETE FROM admin WHERE committed = 'f'");
}

# Method: pendingActions
sub pendingActions
{
	my $dbengine = EBox::DBEngineFactory::DBEngine();
	my $ret = $dbengine->query("SELECT * FROM admin WHERE committed = 'false' ORDER BY module,timestamp");

	my $global = EBox::Global->getInstance(1);

	# group the actions by module and add the title of the module
	my $actions = {};
	foreach my $action (@{$ret}) {
		my $modname = $action->{'module'};
		if(!defined($actions->{$modname})) {
			$actions->{$modname} = {};
			$actions->{$modname}->{'actions'} = [];
		}

		if($global->modExists($modname)) {
			my $mod = EBox::Global->modInstance($modname);
			$action->{$modname}->{'title'} = __d($mod->title(), $mod->domain());
		} else {
			$action->{$modname}->{'title'} = $modname;
		}
		push(@{$actions->{$modname}}, $action);
	}
	return $actions;
}

1;
