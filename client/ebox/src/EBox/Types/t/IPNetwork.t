# Copyright (C) 2008 Warp Networks S.L.
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


use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::IPNetwork;

EBox::TestStubs::activateTestStubs();

my %validNetworks = (
		     '192.168.45.0' => 24,
		     '40.24.3.128' => 25,
		     
		    );

my %invalidNetworks = (
		       '192.168.45.1' => 24,
	    	     '40.24.3.129' => 25,
		      );


while (my ($ip, $mask) = each %validNetworks) {
    lives_ok {
	_create(
				    fieldName => 'test',
				    ip   => $ip,
				    mask => $mask,
				   );

    } "Checking instance creation with valid parameters ip => $ip, mask => $mask";
}

while (my ($ip, $mask) = each %invalidNetworks) {
    dies_ok {
	_create(
		fieldName => 'test',
		printableName => 'test',
		ip   => $ip,
		mask => $mask,
	       );


	
    } "Checking instance creation raises error when called with invalid parameters ip => $ip, mask => $mask";
}


sub _create
{
    my %params = @_;
    
    my $ipn = EBox::Types::IPNetwork->new(
					  %params
					 );
    
    my $ipParamName   = $ipn->fieldName() . '_ip';
    my $maskParamName = $ipn->fieldName() . '_mask';
    
    $ipn->setMemValue({
		       $ipParamName    => $params{ip},
		       $maskParamName => $params{mask},
		      });
}




1;
