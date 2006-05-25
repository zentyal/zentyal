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

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'openvpn');
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
    
    _writeServersConfFiles();
}


sub _writeServersConfFiles
{
    my ($self) = @_;

    my $confDir = $self->get_string('confDir');

    my @servers = $self->_serversNames();
    foreach my $serverName (@servers) {
	my $server = $self->_server($serverName);
	$server->writeConfFile($confDir);
    }
}


sub _serversNames
{
    my ($self) = @_;
    
    my @serversNames = @{ $self->all_dirs_base('servers') };
    return @serversNames;
}

sub _server
{
    my ($self, $name) = @_;
    
    my $server = new EBox::OpenVPN::Server ($name, $self);
    return $server;
}


sub summary
{
	my ($self) = @_;
	my $item = new EBox::Summary::Module(__("ModuleName stuff"));
	return $item;
}

sub rootCommands
{
	my ($self) = @_;
	my @array = ();
	push(@array, "/bin/true");
	return @array;
}

1;
