# Copyright (C) 2007 Warp Networks S.L.
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

# Unit test to check the Objects API exposition

use strict;
use warnings;

use lib '../../';

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use EBox::Global;

BEGIN {
    diag ( 'Starting objects test unit' );
    use_ok ( 'EBox::Objects' );
}

my $objMod = EBox::Global->modInstance('objects');

isa_ok ( $objMod, 'EBox::Objects' );

my $addedId;
ok ( $addedId = $objMod->addObject1( name => 'a',
                                     members => [
                                                 {
                                                  name   => 'a1',
                                                  ipaddr => '192.168.1.1/32',
                                                 },
                                                 {
                                                  name   => 'a2',
                                                  ipaddr => '192.168.1.2/32',
                                                 },
                                                 {
                                                  name   => 'a3',
                                                  ipaddr => '192.168.1.3/32',
                                                 },
                                                ]
                                   ), 'Adding an object with three members');
my @objectNames = map { $_->{name} } @{$objMod->objects()};
cmp_deeply ( \@objectNames,
             supersetof('a'), 'The object addition was done correctly');

my $memberId;
ok ( $memberId = $objMod->addMember( 'a', name => 'a4', ipaddr => '192.168.1.4/32',
                                     macaddr => 'DE:AD:00:00:DE:AF'),
     'Adding member a4 to object a');

cmp_deeply ( subsetof(@{$objMod->objectMembers($addedId)}), bag( { name => 'a4',
                                                     ip   => '192.168.1.4',
                                                     mask => '32',
                                                     mac  => 'DE:AD:00:00:DE:AF'
                                                   } )),
             'The member addition was done correctly');

cmp_ok ( $objMod->objectDescription1( $addedId )->value(), 'eq', 'a',
         'ObjectDescription exposure works');

lives_ok {
    $objMod->setMemberIP( 'a', 'a4', ipaddr => '192.168.1.114/32' ),
} 'Setting an IP address to a member';

cmp_deeply ( $objMod->objectMembers($addedId), supersetof(
                                                          { name => 'a4',
                                                            ip   => '192.168.1.114',
                                                            mask => 32,
                                                            mac  => 'DE:AD:00:00:DE:AF'
                                                          }),
             'The member update was done correctly');

1;


