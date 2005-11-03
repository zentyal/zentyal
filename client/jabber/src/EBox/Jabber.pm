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

package EBox::Jabber;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Gettext;
use EBox::Menu::Item;
use EBox::Service;
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Sudo qw ( :all );

use constant JABBERC2SCONFFILE => '/etc/jabberd2/c2s.xml';
use constant JABBERSMCONFFILE => '/etc/jabberd2/sm.xml';

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'jabber',
					  domain => 'ebox-jabber',
					  @_);
	bless($self, $class);
	return $self;
}

sub daemons # (action)
{
	my ($self, $action) = @_;

	EBox::Service::manage('jabber-router', $action);
	EBox::Service::manage('jabber-resolver', $action);
	EBox::Service::manage('jabber-sm', $action);
	EBox::Service::manage('jabber-s2s', $action);
	EBox::Service::manage('jabber-c2s', $action);
}

sub _doDaemon
{
	my $self = shift;

	if ($self->service and EBox::Service::running('jabber-c2s')) {
		$self->daemons('restart');
	} elsif ($self->service) {
		$self->daemons('start');
	} elsif (EBox::Service::running('jabber-c2s')){
		$self->daemons('stop');
	}
}

sub setService
{
	my ($self, $active) = @_;
	($active and $self->service) and return;
	(!$active and !$self->service) and return;
	$self->set_bool('active', $active);
#	$self->_configureFirewall;
}

sub service
{
	my $self = shift;
	return $self->get_bool('active');
}

sub _regenConfig
{
	my $self = shift;

	$self->_setJabberConf;
	$self->_doDaemon();
}

sub _setJabberConf
{
	my $self = shift;
	my @array = ();

	$self->writeConfFile(JABBERC2SCONFFILE,
			     "jabber/c2s.xml.mas",
			     \@array);
	$self->writeConfFile(JABBERSMCONFFILE,
			     "jabber/sm.xml.mas",
			     \@array);
}

sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('jabber', __('Jabber')),
		EBox::Service::running('jabber-c2s', $self->service);
}

sub summary
{
	my $self = shift;
	my $item = new EBox::Summary::Module(__("Jabber service"));
	return $item;
}

sub rootCommands
{
	my $self = shift;
	my @array = ();
	push(@array, $self->rootCommandsForWriteConfFile(JABBERC2SCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(JABBERSMCONFFILE));
	return @array;
}

sub menu
{
	my ($self, $root) = @_;
	$root->add (new EBox::Menu::Item('url' => 'Jabber/Index',
					 'text' => __('Jabber Service')));
}

1;
