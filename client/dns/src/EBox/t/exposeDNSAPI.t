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

use Test::More tests => 24;
use Test::Exception;
use Test::Deep;

use Perl6::Junction qw(none);

use EBox::Global;

BEGIN {
    diag( 'Starting dns test unit' );
    use_ok( 'EBox::DNS' );
}

my $dnsMod = EBox::Global->modInstance('dns');

isa_ok( $dnsMod, 'EBox::DNS' );

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
                                ],
                   mailExchangers => [
                                      {
                                       hostName   => { custom => 'mail.foobar.net' },
                                       preference => 10,
                                      },
                                      {
                                       hostName   => { ownerDomain => 'a' },
                                       preference => 5,
                                      },
                                     ],
                  );

ok( $addedId = $dnsMod->addDomain1( @domainToAdd ),
     'Adding dns domain "foo.com" with three mappings which include some aliases and MX records');

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

ok( $dnsMod->addHostName( 'foo.com',
                           hostname => 'd',
                           ipaddr   => '192.168.1.4',
                           alias    => [
                                        { alias => 'd1' },
                                        { alias => 'd2' },
                                       ]),
     'Adding hostname d was done correctly');

lives_ok {
    $dnsMod->changeName( '/foo.com/b', 'bbb' );
} 'Change name to a hostname from "b" to "bbb"';

ok( $dnsMod->addAlias( '/foo.com/d',
                        alias => 'd3'),
     'Adding alias d3 to hostname d');

lives_ok {
    $dnsMod->changeAlias( '/foo.com/d/d3', 'dd3');
} 'Changing alias name from d3 to dd3';

cmp_ok( $dnsMod->findAlias( 'foo.com', 'dd3' ), 'eq', 'd',
        'Changing was done correctly' );

throws_ok {
    $dnsMod->findAlias( 'baa', 'ada')
} 'EBox::Exceptions::DataNotFound', 'Find an alias in a non existant domain';

throws_ok {
    $dnsMod->findAlias( 'foo.com', 'ada')
} 'EBox::Exceptions::DataNotFound', 'Find a non-existant alias';

lives_ok {
    $dnsMod->removeAlias( '/foo.com/d/dd3');
} 'Removing alias dd3 correctly';

throws_ok {
      $dnsMod->removeAlias( '/foo.com/d/dd3');
  } 'EBox::Exceptions::DataNotFound', 'Removing an inexistant alias dd3';

lives_ok {
    $dnsMod->setIP( '/foo.com/d', '192.168.4.4' );
} 'Setting a different mapping on hostname d';

cmp_ok( $dnsMod->getHostNameByName('/foo.com/d')->{plainValueHash}->{ipaddr}, 'eq',
        '192.168.4.4', 'Updating ip address on hostname d was done correctly');

cmp_ok( $dnsMod->getHostNameByIP('/foo.com/192.168.4.4')->{plainValueHash}->{hostname},
        'eq', 'd', 'Getting a hostname mapping by IP address');

lives_ok {
    $dnsMod->removeHostName('/foo.com/a');
} 'Removing hostname a';

throws_ok {
    $dnsMod->removeHostName('/foo.com/a');
} 'EBox::Exceptions::DataNotFound', 'Removing an inexistant host a';

ok( $dnsMod->addMailExchanger( 'foo.com',
                               hostName => { ownerDomain => 'bbb' },
                               preference => 100),
    'Adding mail exchanger "b" to the domain from the same domain');

ok( $dnsMod->addMailExchanger( 'foo.com',
                               hostName => { custom => 'another.mailserver.com' },
                               preference => 10),
    'Adding mail exchanger "another.mailserver.com" to the domain from a foreign domain');

lives_ok {
    $dnsMod->changeMXPreference( 'foo.com/another.mailserver.com', 102);
} 'Change the preference attribute to "another.mailserver.com" MX record';

lives_ok {
    $dnsMod->removeMailExchanger('foo.com/another.mailserver.com');
} 'Remove "another.mailserver.com" MX records';

throws_ok {
    $dnsMod->removeMailExchanger('foo.com/another.mailserver.com');
} 'EBox::Exceptions::DataNotFound', 'Removing an already deleted "another.mailserver.com" record';

lives_ok {
    $dnsMod->removeDomain( 'foo.com' );
} 'Removing "foo.com" domain';

cmp_ok( none ( map { $_->{name} } @{$dnsMod->domains()}),
         'eq', 'foo.com',
         '"foo.com" removal was done correctly');

1;


