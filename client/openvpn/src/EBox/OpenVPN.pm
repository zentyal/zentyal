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

package EBox::OpenVPN;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Gettext;
use EBox::Summary::Module;
use Perl6::Junction qw(any);
use EBox::OpenVPN::Server;
use Error qw(:try);

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'openvpn');
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
    my ($self) = @_;

    $self->_writeServersConfFiles();
    $self->_doDaemon();
}

sub confDir
{
    my ($self) = @_;
    return $self->get_string('conf_dir');
}


sub openvpnBin
{
   my ($self) = @_;
   return $self->get_string('openvpn_bin');
}


sub _writeServersConfFiles
{
    my ($self) = @_;

    my $confDir = $self->confDir;

    my @servers = $self->_serversNames();
    foreach my $serverName (@servers) {
	my $server = $self->_server($serverName);
	$server->writeConfFile($confDir);
    }
}


sub serversNames
{
    my ($self) = @_;
    
    my @serversNames = @{ $self->all_dirs_base('server') };
    return @serversNames;
}

# a object server cache may be a good idea?
sub server
{
    my ($self, $name) = @_;
    
    my $server = new EBox::OpenVPN::Server ($name, $self);
    return $server;
}



sub newServer
{
    my ($self, $name, %params) = @_;
    my $type = exists $params{type} ? delete $params{type} : 'one2many'; # type is ignored for now.. Now we use only a type of server

    unless ( $name =~ m{^\w+$} ) {
	throw EBox::Exceptions::External (__x("{name} is a invalid name for a server. Only alphanumerics and underscores are allowed", name => $name) );
    }

    my @serversNames = $self->serversNames();
    if ($name eq any(@serversNames)) {
	throw EBox::Exceptions::DataExists(data => "OpenVPN server", value => $name  );
    }
    
    $self->set_string("server/$name/type" => $type);
    my $server;
    try {
	$server = $self->server($name);
	$server->setFundamentalAttributes(%params);
    }
    otherwise {
	my  $ex = shift;
	$self->delete_dir("server/$name");
	$ex->throw();
    };

    return $server;
}


sub removeServer
{
    my ($self, $name) = @_;
    my $serverDir = "server/$name";

    if (! $self->dir_exists($serverDir)) {
	throw EBox::Exceptions::External __x("Unable to remove because there is not a openvpn server named {name}", name => $name);
    }

	
    $self->delete_dir($serverDir);
}

sub user
{
    my ($self) = @_;
    return $self->get_string('user');
}

sub group
{
    my ($self) = @_;
    return $self->get_string('group');
}


sub summary
{
	my ($self) = @_;
	my $item = new EBox::Summary::Module(__("ModuleName stuff"));
	return $item;
}


sub setService # (active)
{
    my ($self, $active) = @_;
    ($active and $self->service)   and return;
    (!$active and !$self->service) and return;

    $self->set_bool('active', $active);
#   $self->_configureFirewall;
}


sub service
{
   my ($self) = @_;
   return $self->get_bool('active');
}

sub _doDaemon
{
    my ($self) = @_;
    my $running = EBox::Service::running('openvpn');

    if ($self->service) {
	if ($running) {
	    EBox::Service::manage('openvpn', 'restart');
	}
	else {
	EBox::Service::manage('openvpn', 'start');
	}
    }
    else {
	if ($running) {
	    EBox::Service::manage('openvpn', 'stop');
	  }
    }

}

sub _stopService
{
    EBox::Service::manage('openvpn','stop');
}


sub rootCommands
{
	my ($self) = @_;
	my @commands = ();
	push @commands, $self->rootCommandsForWriteConfFile($self->confDir . '/*');
	
	#XXX TODO: add doDaemon commands

	return @commands;
}

1;
