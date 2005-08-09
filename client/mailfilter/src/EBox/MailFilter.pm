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

package EBox::MailFilter;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Gettext;
#use EBox::Sudo qw( :all );
#use EBox::Validate qw( :all );
use EBox::Summary::Module;
use EBox::Summary::Status;

use constant AMAVISPIDFILE			=> "/var/run/amavis/amavisd.pid";
use constant SAPIDFILE				=> "/var/run/spamd.pid";
use constant CLAMAVPIDFILE			=> "/var/run/clamav/clamd.pid";

#
# Method: _create
#
#  Constructor of the class
#
sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'mailfilter');
	bless($self, $class);
	return $self;
}

#
# Method: _regenConfig
#
sub _regenConfig
{
}


#
# Method: isRunning
#
#  Returns if the module is running.
#
# Returns:
#
#  boolean - true if it's running, otherwise false
#
sub isRunning
{
	my $self = shift;

	if ($self->pidFileRunning(AMAVISPIDFILE) and $self->pidFileRunning(SAPIDFILE)
			and $self->pidFileRunning(CLAMAVPIDFILE)) {
		return 1;
	}

	return 0;
}

#
# Method: service
#
#  Returns the state of the service.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub service
{
	my $self = shift;
	return $self->get_bool('active');
}

#
# Method: setService
#
#  Enable/Disable the service.
#
# Parameters:
#
#  active - true or false
#
sub setService 
{
	my ($self, $active) = @_;
	($active and $self->service()) and return;
	(!$active and !$self->service()) and return;
	$self->set_bool('active', $active);
}

#
# Method: summary
#
#  Returns an EBox::Summary::Module to add to the summary page. This class
#  contains information about the state of the module
#
# Returns:
#
#  EBox::Summary::Module instance.
#
#sub summary
#{
#	my $self = shift;
#	my $item = new EBox::Summary::Module(__("Mail"));
#	my $section = new EBox::Summary::Section();
#
#	$item->add($section);
#
#	my $mailfilter = new EBox::Summary::Status('mail', __('MailFilter system'),
#		$self->isRunning(), $self->service());
#
#	$section->add($mailfilter);
#
#	return $item;
#}

#
# Method: statusSummary
#
#	Returns an EBox::Summary::Status to add to the services section of the
#	summary page. This class contains information about the state of the
#	module.
#
# Returns:
#
#	EBox::Summary::Status instance.
#
sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('mailfilter', __('Mail filter system'),
		$self->isRunning(), $self->service());
}

#
# Method: menu
#
#	This method add a mailfilter item to the Mail folder in the menu.
#
sub menu
{
	my ($self, $root) = @_;
	my $folder = new EBox::Menu::Folder('name' => 'Mail',
		'text' => __('Mail'));
	$folder->add(new EBox::Menu::Item('url' => 'MailFilter/Index',
			'text' => __('Mail filter')));
	$root->add($folder);
}

#
# Method: rootCommands
#
#	Creates an array with the full path of commands with their parameters
#	that the module need to run with superuser privileges.
#
# Returns:
#
#	array with the commands.
#
sub rootCommands
{
	my $self = shift;
	my @array = ();
	push(@array, "/bin/true");
	return @array;
}

1;
