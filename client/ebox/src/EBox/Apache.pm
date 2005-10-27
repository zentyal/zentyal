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

package EBox::Apache;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Validate qw( :all );
use EBox::Sudo qw( :all );
use POSIX qw(setsid);
use EBox::Global;
use HTML::Mason::Interp;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'apache', @_);
	bless($self, $class);
	return $self;
}

sub serverroot
{
	my $root = EBox::Config::configkey('httpd_serverroot');
	($root) or
		throw EBox::Exceptions::External(__('You must set the '.
		'httpd_serverroot variable in the ebox configuration file'));
	return $root;
}

#not used now
sub initd
{
	my $initd = EBox::Config::configkey('httpd_init');
	($initd) or
		throw EBox::Exceptions::External(__('You must set the '.
			'httpd_init variable in the ebox configuration file'));
	( -x $initd ) or
		throw EBox::Exceptions::External(__('The httpd_init script'.
			' you configured is not executable.'));
	return $initd;
}

# restarting apache from inside apache could be problematic, so we fork() and
# detach the child from the process group.
sub _daemon # (action) 
{
	my $self = shift;
	my $action = shift;
	my $pid;
	my $fork = undef;
	exists $ENV{"MOD_PERL"} and $fork = 1;

	if ($fork) {
		unless (defined($pid = fork())) {
			throw EBox::Exceptions::Internal("Cannot fork().");
		}
	
		if ($pid) { 
			return; # parent returns inmediately
		}

		POSIX::setsid();
		close(STDOUT);
		close(STDERR);
		open(STDOUT, "> /dev/null");
		open(STDERR, "> /dev/null");
		sleep(5);
	}

	if ($action eq 'stop') {
		root("/usr/bin/runsvctrl down /var/service/apache-perl");
	} elsif ($action eq 'start') {
		root("/usr/bin/runsvctrl up /var/service/apache-perl");
	} elsif ($action eq 'restart') {
		exec(EBox::Config::libexec . 'ebox-apache-restart');
	}

	if ($fork) {
		exit 0;
	}
}

sub _stopService
{
	my $self = shift;
	$self->_daemon('stop');
}

sub _regenConfig
{
	my $self = shift;

	my $httpdconf = EBox::Config::configkey('httpd_conf');
	my $output;
	my $interp = HTML::Mason::Interp->new(out_method => \$output);
	my $comp = $interp->make_component(
			comp_file => (EBox::Config::stubs . '/apache.mas'));
	my @array = ();
	push(@array, port=>$self->port);
	push(@array, user=>EBox::Config::user);
	push(@array, group=>EBox::Config::group);
	push(@array, serverroot=>$self->serverroot);
	$interp->exec($comp, @array);
	my $confile = EBox::Config::tmp . "httpd.conf";
	unless (open(HTTPD, "> $confile")) {
		throw EBox::Exceptions::Internal("Could not write to $confile");
	}
	print HTTPD $output;
	close(HTTPD);

	root("/bin/mv $confile $httpdconf");

	$self->_daemon('restart');
}

sub port
{
	my $self = shift;
	return $self->get_int('port');
}

sub setPort # (port) 
{
	my ($self, $port) = @_;

	checkPort($port, __("port"));
	my $fw = EBox::Global->modInstance('firewall');

	if ($self->port() == $port) {
		return;
	}

	if (defined($fw)) {
		unless ($fw->availablePort("tcp",$port)) {
			throw EBox::Exceptions::DataExists(data => __('port'),
							   value => $port);
		}
		$fw->changeService("administration", "tcp", $port);
	}

	$self->set_int('port', $port);
}

sub rootCommands 
{
	my $self = shift;
	my $initd = $self->initd;
	my $confile = EBox::Config::tmp . "httpd.conf";
	my $httpdconf = EBox::Config::configkey('httpd_conf');

	my @array = ();
	push(@array, $initd);
	push(@array, "/bin/mv $confile $httpdconf");
	return @array;
}

sub logs {
	my @logs = ();
	my $log;
	$log->{'module'} = 'apache';
	$log->{'table'} = 'access';
	$log->{'file'} = EBox::Config::log . "/access.log";
	my @fields = qw{ host www_user date method url protocol code size referer ua };
	$log->{'fields'} = \@fields;
	$log->{'regex'} = '(.*?) - (.*?) \[(.*)\] "(.*?) (.*?) (.*?)" (.*?) (.*?) "(.*?)" "(.*?)" "-"';
	my @types = qw{ inet varchar timestamp varchar varchar varchar integer integer varchar varchar };
	$log->{'types'} = \@types;
	push(@logs, $log);
	return \@logs;
}
1;
