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

package EBox::CGI::Firewall::ObjectService;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Firewall;
use EBox::Objects;
use EBox::Gettext;
use EBox::Exceptions::DataNotFound;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('template' => '/firewall/objectService.mas',
				      @_);
	$self->{domain} = 'ebox-firewall';	
	$self->{errorchain} = "Firewall/Filter";
	bless($self, $class);
	return $self;
}



sub requiredParameters
{
  return [qw(object)];
}

sub optionalParameters
{
  return [qw(configobject)];
}



sub _react
{
	my $self = shift;


	my $objname = $self->_objname();

	if ($objname eq "_global") {
		$self->{title} = __(q{Global services' filtering rules});
	} 
	else {
	  my $objects = EBox::Global->modInstance('objects');
	  my $description = $objects->objectDescription($objname);
	  $self->{title} = __x(q{Services' filtering rules {desc}}, 
					desc => $description);
	}


}



sub masonParameters
{
  my ($self) = @_;

  my $firewall = EBox::Global->modInstance('firewall');


  my @servs = @{ $firewall->services() };
  my $objname = $self->_objname;
  my $objectservs = $firewall->ObjectServices($objname);

  
  @servs = grep {  not $firewall->serviceIsInternal($_->{name}) } @servs; # get rid of internal services
  @servs = map  {  $_->{name} } @servs; # we just want the service name


  my @params = ();
  defined($objectservs) and push @params, ('servicepol' => $objectservs);
  
  push @params, ('object' => $self->_objname());
  push @params, ('services' => \@servs);
  
  
  return \@params;
}


sub _objname
{
  my ($self) = @_;

  my $objname = $self->param('object');

  return $objname if $objname eq '_global';

  my $objects = EBox::Global->modInstance('objects');
  unless ($objects->objectExists($objname)|| $objname eq "_global") {
    throw EBox::Exceptions::DataNotFound('data' => __('Object'),
					 'value' => $objname);
  }

  return $objname;
}


1;
