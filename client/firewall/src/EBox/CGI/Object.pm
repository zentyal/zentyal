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

package EBox::CGI::Firewall::Object;

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
	my $self = $class->SUPER::new('template' => '/firewall/object.mas',
				      @_);
	$self->{domain} = 'ebox-firewall';	
	$self->{errorchain} = "Firewall/Filter";
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $firewall = EBox::Global->modInstance('firewall');
	my $objects = EBox::Global->modInstance('objects');

	$self->_requireParam('object', __('Object'));

	my $objname = $self->param("object");

	unless ($objects->objectExists($objname)|| $objname eq "_global") {
		throw EBox::Exceptions::DataNotFound('data' => __('Object'),
			'value' => $objname);
	}

	my $description;

	if ($objname ne '_global') {
		$description = $objects->ObjectDescription($objname);
	}

	if ($objname eq "_global") {
		$self->{title} = __('Global firewall configuration');
	} else {
		$self->{title} = __x('Firewall configuration: {desc}', 
					desc => $description);
	}

	my $object = $firewall->Object($objname);
	my $servs = $firewall->services();
	my $rules = $firewall->ObjectRules($objname);
	my $objectservs = $firewall->ObjectServices($objname);
	my $policy = $firewall->ObjectPolicy($objname);

	my @tmp = ();
	foreach (@{$servs}) {
		delete($_->{protocol});
		delete($_->{port});
		if (defined($_->{dnatport})) {
			delete($_->{dnatport});
		}
		unless ($firewall->serviceIsInternal($_->{name})) {
			push(@tmp, $_)
		}
	}
	$servs = \@tmp;

	my @array = ();

	defined($rules) and push(@array, 'rules' => $rules);
	defined($objectservs) and push(@array, 'servicepol' => $objectservs);

	push(@array, 'object' => $objname);
	push(@array, 'services' => $servs);
	push(@array, 'policy' => $policy);

	$self->{params} = \@array;
}

1;
