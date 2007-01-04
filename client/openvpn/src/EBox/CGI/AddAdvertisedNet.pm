# Copyright (C) 2005 Warp Networks S.L.
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

package EBox::CGI::OpenVPN::AddAdvertisedNet;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::OpenVPN;


## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'OpenVPN',
				      @_);
	$self->{domain} = "ebox-openvpn";	 

	$self->{chain} = "OpenVPN/Index";   # because we can get the server's name in this stage

	bless($self, $class);
	return $self;
}

sub actuate
{
    my ($self) = @_;

    my $serverName  = $self->param('name');

    my $editServerUrl = "OpenVPN/Edit?name=$serverName";
    $self->setChain($editServerUrl);
    $self->setErrorchain($editServerUrl);
    
 
    my $network = $self->param('network');
    my $netmask = $self->param('netmask');

    my $openvpn = EBox::Global->modInstance('openvpn');
    my $server  = $openvpn->server($serverName);
    $server->addAdvertisedNet($network, $netmask);
      
    $self->setMsg(__x('Server now grants access to {network}', network => $network));
}


sub requiredParameters
{
    return [qw(name network netmask)]; 
}


sub optionalParameters
{
    return [ 'submit']; # change is the parameter related to the input button
}

1;
