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
use EBox::Sudo qw( :all );
#use EBox::Validate qw( :all );
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Exceptions::InvalidData;

use constant AMAVISPIDFILE			=> "/var/run/amavis/amavisd.pid";
use constant SAPIDFILE				=> "/var/run/spamd.pid";
use constant CLAMAVPIDFILE			=> "/var/run/clamav/clamd.pid";
use constant AMAVISINIT				=> '/etc/init.d/amavis';
use constant SAINIT					=> '/etc/init.d/spamassassin';
use constant CLAMAVINIT				=> '/etc/init.d/clamav-daemon';

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
	my $self = shift;

#	@array = ();
#	$self->writeConfFile(AMAVISCONFFILE, "mailfilter/amavisd.conf.mas", \@array);

	$self->_doDaemon();
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

	return (($self->pidFileRunning(AMAVISPIDFILE)) and
		($self->pidFileRunning(SAPIDFILE)) and
		($self->pidFileRunning(CLAMAVPIDFILE)));
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
# Method: _doDaemon
#
#  Sends restart/start/stop command to the daemons depending of their actual
#  state and the state stored in gconf
#
sub _doDaemon
{
	my $self = shift;

	if ($self->service() and $self->isRunning()) {
		$self->_daemon('restart');
	} elsif ($self->service()) {
		$self->_daemon('start');
	} elsif ($self->isRunning()) {
		$self->_daemon('stop');
	}
}

#
# Method: _daemon
#
#  Execute the action passed as parameter to the service daemons
#
# Parameters:
#
#  action - restart/start/stop
#
sub _daemon
{
	my ($self, $action) = @_;

	my $amaviscmd = AMAVISINIT . " " . $action . " 2>&1";
	my $sacmd = SAINIT . " " . $action . " 2>&1";
	my $clamavcmd = CLAMAVINIT . " " . $action . " 2>&1";
	
	if ( $action eq 'start') {
		root($clamavcmd);
		root($sacmd);
		root($amaviscmd);
	} elsif ( $action eq 'stop') {
		root($clamavcmd);
		root($sacmd);
		root($amaviscmd);
	} elsif ( $action eq 'restart') {
		root($clamavcmd);
		root($sacmd);
		root($amaviscmd);
	} else {
		throw EBox::Exceptions::Internal("Bad argument: $action");
	}
}

#
# Method: _stopService
#
#  Stops the service daemons
#
sub _stopService
{
	my $self = shift;
	if ($self->isRunning('active')) {
		$self->_daemon('stop');
	}
}

#
# Method: bayes
#
#  Returns the state of the bayesian filter.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub bayes
{
	my $self = shift;
	return $self->get_bool('bayes');
}

#
# Method: setBayes
#
#  Enable/Disable the bayesian filter.
#
# Parameters:
#
#  active - true or false
#
sub setBayes
{
	my ($self, $active) = @_;
	($active and $self->bayes()) and return;
	(!$active and !$self->bayes()) and return;
	$self->set_bool('bayes', $active);
}

#
# Method: updateVirus
#
#  Returns the state of the automatic virus signs database.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub updateVirus
{
	my $self = shift;
	return $self->get_bool('updatevirus');
}

#
# Method: setUpdateVirus
#
#  Enable/Disable the automatic virus signs database
#
# Parameters:
#
#  active - true or false
#
sub setUpdateVirus
{
	my ($self, $active) = @_;
	($active and $self->updateVirus()) and return;
	(!$active and !$self->updateVirus()) and return;
	$self->set_bool('updatevirus', $active);
}

#
# Method: mode
#
#  Returns the mode of MailFilter system.
#
# Returns:
#
#  boolean - true: working as filter proxy to an external mail system.
#  			 false: working with an eBox Mail module.
#
sub moduleMode
{
	my $self = shift;
	return $self->get_bool('mode');
}

#
# Method: setModuleMode
#
#  Sets the working mode of the MailFilter module.
#
# Parameters:
#
#  active - true: working as filter proxy to an external mail system.
#  			false: working with an eBox Mail module.
#
sub setModuleMode
{
	my ($self, $active) = @_;
	($active and $self->moduleMode()) and return;
	(!$active and !$self->moduleMode()) and return;
	$self->set_bool('mode', $active);
}

#
# Method: autolearn
#
#  Returns the state of the autolearn in bayesian subsystem.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub autolearn
{
	my $self = shift;
	return $self->get_bool('autolearn');
}

#
# Method: setAutolearn
#
#  Enable/Disable autolearn in bayesian subsystem.
#
# Parameters:
#
#  active - true or false
#
sub setAutolearn
{
	my ($self, $active) = @_;
	($active and $self->autolearn()) and return;
	(!$active and !$self->autolearn()) and return;
	$self->set_bool('autolearn', $active);
}

#
# Method: autoSpamHits
#
#  Returns the hits that a spam message would have to obtain to enter to the
#  learning system.
#
# Returns:
#
#  string - The score.
#
sub autoSpamHits
{
	my $self = shift;
	return $self->get_string('autospamhits');
}

#
# Method: setAutoSpamHits
#
#  Sets the hits score that a spam message would have to obtain to enter to the
#  learning system.
#
# Parameters:
#
#  hits - A string contains the hits score.
#
sub setAutoSpamHits
{
	my ($self, $hits) = @_;
	($hits eq $self->autoSpamHits()) and return;
	$self->set_string('autospamhits', $hits);
}

#
# Method: autoHamHits
#
#  Returns the hits that a ham message would have to obtain to enter to the
#  learning system.
#
# Returns:
#
#  string - The score.
#
sub autoHamHits
{
	my $self = shift;
	return $self->get_string('autohamhits');
}

#
# Method: setAutoHamHits
#
#  Sets the hits score that a ham message would have to obtain to enter to the
#  learning system.
#
# Parameters:
#
#  hits - A string contains the hits score.
#
sub setAutoHamHits
{
	my ($self, $hits) = @_;
	($hits eq $self->autoHamHits()) and return;
	$self->set_string('autohamhits', $hits);
}

#
# Method: subjectModification
#
#  Returns the modification of the subject state
#  
# Returns:
#
#  boolean - true if its active, false otherwise
#
sub subjectModification
{
	my $self = shift;
	return $self->get_bool('subjectmod');
}

#
# Method: setSubjectModification
#
#  Sets the modification of the subject parameter.
#
# Parameters:
#
#  sbmod - true if the modification is active, false otherwise
#
sub setSubjectString
{
	my ($self, $sbmod) = @_;
	($sbmod and $self->subjectModification()) and return;
	(!sbmod and !$self->subjectModification()) and return;
	$self->set_bool('subjectmod', $sbmod);
}


#
# Method: subjectString
#
#  Returns the string to add to the subject of a spam message (if this option is
#  active)
#  
# Returns:
#
#  string - The string to add.
#
sub subjectString
{
	my $self = shift;
	return $self->get_string('subjectstr');
}

#
# Method: setSubjectString
#
#  Sets the string to add to the subject of a spam message.
#
# Parameters:
#
#  subject - A string to add.
#
sub setSubjectString
{
	my ($self, $subject) = @_;
	($subject eq $self->subjectString()) and return;
	$self->set_string('subjectstr', $subject);
}

#
# Method: filterPolicy
#
#  Returns the policy of a filter type passed as parameter. The filter type
#  could be:
#  	- virus: Virus filter.
#  	- spam: Spam filter.
#  	- bhead: Bad headers checks.
#  	- banned: Banned names and types checks.
#  And the policy:
#  	- PASS
#		- REJECT
#  	- BOUNCE
#
# Parameters:
# 
#  ftype - A string with filter type.
#   
# Returns:
#
#  string - The string with the policy established to the filter type.
#
sub filterPolicy
{
	my ($self, $ftype) = shift;
	my @ftypes = ('virus', 'spam', 'bhead', 'banned');

	if (grep(/^$ftype$/, @ftypes)) {
		return $self->get_string($ftype.'policy');
	} else {
      throw EBox::Exceptions::InvalidData(
         'data'  => __('filter type'),
         'value' => $ftype);
	}
}

#
# Method: setFilterPolicy
#
#  Sets the policy to a filter type. (see filterPolicy method to filter types
#  and policies details.)
#
# Parameters:
#
#  ftype - A string with the filter type.
#  policy - A string with the policy.
#
sub setFilterPolicy
{
	my ($self, $ftype, $policy) = @_;
	my @ftypes = ('virus', 'spam', 'bhead', 'banned');
	my @policies = ('PASS', 'REJECT', 'BOUNCE');
	
	($policy eq $self->filterPolicy($ftype)) and return;

	if (grep(/^$ftype$/, @ftypes)) {
		if (grep(/^$policy$/, @policies)) {
			$self->set_string($ftype.'policy', $policy);
		} else {
			throw EBox::Exceptions::InvalidData(
				'data'  => __('policy type'),
				'value' => $policy);
		}
	} else {
      throw EBox::Exceptions::InvalidData(
         'data'  => __('filter type'),
         'value' => $ftype);
	}
}

# Method: hitsThrowPolicy
#
#  Returns the minimum hits to throw the selected policy.
#  
# Returns:
#
#  string - The score.
#
sub hitsThrowPolicy
{
	my $self = shift;
	return $self->get_string('hitspolicy');
}

#
# Method: setHitsThrowPolicy
#
#  Sets the minimum hits to throw the selected policy.
#
# Parameters:
#
#  hits - A string with the hits score.
#
sub setHitsThrowPolicy
{
	my ($self, $hits) = @_;
	($hits eq $self->hitsThrowPolicy()) and return;
	$self->set_string('hitspolicy', $hits);
}

# Method: accountBypassList
#
#  Returns the list of account that bypass the selected list check. There are
#  four types of check so there are four lists: 
#  - Virus check							-> virus (list)
#  - Spam check							-> smap (list)
#  - Bad headers check					-> bhead (list)
#  - Banned files and types check	-> banned (list)
#
# Parameters:
#
#  list - The type of check list to get accounts.
#  
# Returns:
#
#  array ref - Holding the accounts
#
sub accountsBypassList
{
	my ($self, $list) = @_;
	my @ltypes = ('virus', 'spam', 'bhead', 'banned');
	
	if (grep(/^$list$/, @ltypes)) {
		return $self->get_list($list."list");
	} else {
		throw EBox::Exceptions::InvalidData(
			'data'  => __('list type'),
			'value' => $list);
	}
}

# Method: setAccountBypassList
#
#  Sets a list of accounts to bypass the check over it. See accountBypassList to
#  get types of list details.
#
# Parameters:
#
#  list - The list to add to.
#  acocunts - The accounto to bypass the check.
#
sub setAccountsBypassList
{
	my ($self, $list, $accounts) = @_;
	my @ltypes = ('virus', 'spam', 'bhead', 'banned');
	
	if (grep(/^$list$/, @ltypes)) {
		$self->set_list($list."list", "string", $accounts);
	} else {
		throw EBox::Exceptions::InvalidData(
			'data'  => __('list type'),
			'value' => $list);
	}
}

# Method: whitelist
#
#	Returns the list of accounts that are whitelisted. This list is a soft
#	whitelist so with each account has associated a score with the following
#	format: someuser@somedomain.com,score
#
# Returns:
#
#  array ref - Holding the accounts/score pairs.
#
sub whitelist
{
	my $self = shift;
	
	return $self->get_list("whitelist");
}

# Method: setWhitelist
#
#  Sets a list of accounts that are whitelisted. This list is a soft whitelist
#  so with each account has associated a score with the following format:
#  someuser@somedomain.com,score
#
# Parameters:
#
#  acocunts - The account/score pair list to whitelist
#
sub setWhitelist
{
	my ($self, $accounts) = @_;
	
	$self->set_list("whitelist", "string", $accounts);
}

# Method: blacklist
#
#	Returns the list of accounts that are blacklisted. This list is a soft
#	blacklist so with each account has associated a score with the following
#	format: someuser@somedomain.com,score
#
# Returns:
#
#  array ref - Holding the accounts/score pairs.
#
sub blacklist
{
	my $self = shift;
	
	return $self->get_list("blacklist");
}

# Method: setBlacklist
#
#  Sets a list of accounts that are blacklisted. This list is a soft blacklist
#  so with each account has associated a score with the following format:
#  someuser@somedomain.com,score
#
# Parameters:
#
#  acocunts - The account/score pair list to blacklist
#
sub setBlacklist
{
	my ($self, $accounts) = @_;
	
	$self->set_list("blacklist", "string", $accounts);
}

#
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
	push(@array, AMAVISINIT);
	push(@array, SAINIT);
	push(@array, CLAMAVINIT);
	return @array;
}

1;
