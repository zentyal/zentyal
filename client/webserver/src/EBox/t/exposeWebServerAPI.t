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

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use EBox::Global;

BEGIN {
    diag('Starting web server exposed API');
    use_ok('EBox::WebServer');
}

EBox::init();
my $gl = EBox::Global->getInstance();
my $webMod = $gl->modInstance('webserver');
isa_ok( $webMod, 'EBox::WebServer');

my $addedId;
lives_ok { $addedId = $webMod->addVHost( name => 'devendra.banhart.com',
                                         enabled => 1);
       } 'Adding a virtual host';

ok( $addedId, 'Adding was done correctly');

my $vHost;
lives_ok {
    $vHost = $webMod->vHost('devendra.banhart.com');
} 'Getting the virtual host';

ok( $vHost->{plainValueHash}->{enabled}, 'The virtual host is correctly got');

lives_ok {
    $webMod->updateVHost('devendra.banhart.com',
                         enabled => 0);
} 'Updating a virtual host';

ok ( ! $webMod->isVHostEnabled('devendra.banhart.com')->value(),
     'The virtual host is correctly disabled');

SKIP: {
    skip('DNS module is not installed', 4) unless $gl->modExists('dns');
    my $dnsMod = $gl->modInstance('dns');
    my $hostName = $dnsMod->getHostName('banhart.com/devendra');
    ok($hostName, 'Domain and hostname was added correctly');
    lives_ok {
        $webMod->addVHost( name    => 'themistake.banhart.com',
                           enabled => 1);
    } 'Adding another virtual host';
    # Checking an alias was correctly added
    my $aliases = $dnsMod->getHostName('banhart.com/devendra')->{printableValueHash}->{alias}->{values};
    ok( scalar(grep { $_->{alias} eq 'themistake' } @{$aliases}),
      'Alias correctly added');
    lives_ok {
        $webMod->removeVHost( 'themistake.banhart.com' );
    } 'Removing second virtual host';
}

lives_ok {
    $webMod->removeVHost('devendra.banhart.com');
} 'Removing virtual host';

throws_ok {
    $webMod->removeVHost('devendra.banhart.com');
} 'EBox::Exceptions::DataNotFound', 'Removal was done correctly';

# If DNS module is installed remove everything
if ( $gl->modExists('dns') ) {
    my $dnsMod = $gl->modInstance('dns');
    $dnsMod->removeDomain('banhart.com');
}

