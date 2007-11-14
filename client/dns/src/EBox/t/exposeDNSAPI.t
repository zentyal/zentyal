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

# Unit test to check the DNS API exposition

use strict;
use warnings;

use lib '../../';

use Test::More tests => 14;
use Test::Exception;
use Test::Deep;

use Perl6::Junction qw(none);

use EBox::Global;

BEGIN {
    diag ( 'Starting dns test unit' );
    use_ok ( 'EBox::DNS' );
}

my $dnsMod = EBox::Global->modInstance('dns');

isa_ok ( $dnsMod, 'EBox::DNS' );

my $addedId;
my @domainToAdd = (domain => 'foo.com',
                   hostnames => [
                                 {
                                  hostname => 'a',
                                  ipaddr   => '192.168.1.1',
                                  alias    => [
                                               { alias => 'a1' },
                                               { alias => 'a2' }
                                              ],
                                 },
                                 {
                                  hostname => 'b',
                                  ipaddr   => '192.168.1.2',
                                  alias    => [
                                               { alias => 'b1' },
                                              ],
                                 },
                                 {
                                  hostname => 'c',
                                  ipaddr   => '192.168.1.3',
                                  alias    => [
                                               { alias => 'c1' },
                                               { alias => 'c2' },
                                               { alias => 'c3' },
                                              ],
                                 },
                                ]
                  );

ok ( $addedId = $dnsMod->addDomain1( @domainToAdd ),
     'Adding dns domain "foo.com" with three mappings which include some aliases');

# Mapping to check
#my %domainHash = @domainToAdd;
#$domainHash{name} = delete( $domainHash{domain});
#$domainHash{hosts} = delete( $domainHash{hostnames});
#foreach my $host ( @{$domainHash{hosts}} ) {
#    $host->{name} = delete ( $host->{hostname} );
#    $host->{ip}   = delete ( $host->{ipaddr} );
#    $host->{aliases} = [];
#    foreach my $alias (@{$host->{alias}}) {
#        $alias->{name} = delete ( $alias->{alias} );
#        push( @{$host->{aliases}}, $alias);
#    }
#    delete($host->{alias});
#}
#is_deeply ( $dnsMod->completeDomain( { name => 'foo.com' } ), \%domainHash,
#           'Domain added correctly');

ok ( $dnsMod->addHostName( 'foo.com',
                           hostname => 'd',
                           ipaddr   => '192.168.1.4',
                           alias    => [
                                        { alias => 'd1' },
                                        { alias => 'd2' },
                                       ]),
     'Adding hostname d was done correctly');

ok ( $dnsMod->addAlias( '/foo.com/d',
                        alias => 'd3'),
     'Adding alias d3 to hostname d');

lives_ok {
    $dnsMod->changeAlias( '/foo.com/d/d3', 'dd3');
} 'Changing alias name from d3 to dd3';

lives_ok {
    $dnsMod->removeAlias( '/foo.com/d/dd3');
} 'Removing alias dd3 correctly';

throws_ok {
      $dnsMod->removeAlias( '/foo.com/d/dd3');
  } 'EBox::Exceptions::DataNotFound', 'Removing an inexistant alias dd3';

lives_ok {
    $dnsMod->setIP( '/foo.com/d', '192.168.4.4' );
} 'Setting a different mapping on hostname d';

cmp_ok ( $dnsMod->getHostName('/foo.com/d')->{plainValueHash}->{ipaddr}, 'eq',
         '192.168.4.4', 'Updating ip address on hostname d was done correctly');

lives_ok {
    $dnsMod->removeHostName('/foo.com/a');
} 'Removing hostname a';

throws_ok {
    $dnsMod->removeHostName('/foo.com/a');
} 'EBox::Exceptions::DataNotFound', 'Removing an inexistant host a';

lives_ok {
    $dnsMod->removeDomain( 'foo.com' );
} 'Removing "foo.com" domain';

cmp_ok ( none ( map { $_->{name} } @{$dnsMod->domains()}),
         'eq', 'foo.com',
         '"foo.com" removal was done correctly');

1;


