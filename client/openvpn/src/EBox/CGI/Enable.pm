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

package EBox::CGI::OpenVPN::Enable;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'OpenVPN',
				      @_);
	$self->{redirect} = "OpenVPN/Index";	
	$self->{domain} = "ebox-openvpn";	
	bless($self, $class);
	return $self;
}

sub actuate
{
    my ($self) = @_;
    my $openvpn = EBox::Global->modInstance('openvpn');
    my $activeValue = $self->param('active');
    
    my $requestedStatus;
    if ($activeValue eq 'yes') {
	$requestedStatus = 1;
    }
    elsif ($activeValue eq 'no') {
	$requestedStatus = 0;
    }
    else {
	throw EBox::Exceptions::InvalidData(data => __('active parameter'), value => $activeValue, advice => __(q{It only may be 'yes' or 'no'}) );
    }
 
    $openvpn->setUserService($requestedStatus);
}


sub requiredParameters
{
    return ['active']; 
}


sub optionalParameters
{
    return [ 'change']; # change is the parameter related to the input button
}

1;
