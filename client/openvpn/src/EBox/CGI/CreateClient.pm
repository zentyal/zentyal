# Copyright (C) 2006, 2007 Warp Networks S.L.
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

package EBox::CGI::OpenVPN::CreateClient;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
use EBox::Config;
use Perl6::Junction qw(any);
use File::Slurp;
use File::Basename;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('OpenVPN'),
				      'template' => '/openvpn/createClient.mas',
				      @_);

	$self->{domain} = 'ebox-openvpn';
	bless($self, $class);
	return $self;
}


sub requiredParameters
{
    my ($self) = @_;
    if ($self->param('create')) {
	[qw(create name proto caCertificatePath certificatePath certificateKey serverAddr serverPort service)];
    }
    else {
	return [];
    }

}


sub optionalParameters
{
    my ($self) = @_;
    if ($self->param('create')) {
	[qw( service )];
    }
    else {
	return [qw(submit)];
    }
}




sub actuate
{
    my ($self) = @_;
 
    if ($self->param('create')) {
	my $openVPN = EBox::Global->modInstance('openvpn');

	my $anyParamWithUpload = any(qw(caCertificatePath certificatePath certificateKey));

	my $name;
	my %params;

	foreach my $param (@{ $self->params() }) {
	  if ($param eq 'name') {
	    $name = $self->param('name');
	    next;
	  }

	  my $paramValue;
	  if ($param eq $anyParamWithUpload) {
	    $paramValue = $self->upload($param);
	  }
	  else {
	    $paramValue = $self->param($param);
	  }

	  $params{$param} = $paramValue;
	} 


	# for now we only suport one server
	my $serverAddr = delete $params{serverAddr};
	my $serverPort = delete $params{serverPort};
	my @servers = (
		       [$serverAddr => $serverPort],
		      );

	# remove blank parameters
	while (my ($key, $value) = each %params) {
	    next if $value ne '';
	    delete $params{$key};
	}

	$params{internal} = 0; # clients created by UI aren't internal

	$openVPN->newClient($name, servers => \@servers, %params);

    
	$self->setMsg(__x("New client {name} created", name => $name) );
	$self->{chain} = 'OpenVPN/Index';
    }
}




1;

