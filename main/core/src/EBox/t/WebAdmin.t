#!/usr/bin/perl -w

# Copyright (C) 2008-2013 Zentyal S.L.
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

# A module to test restricted resources and includes methods on WebAdmin module

use warnings;
use strict;

use Test::More tests => 37;
use Test::Exception;
use Test::Deep;

use lib '../../..';

use EBox::Global::TestStub;
use EBox::Sudo::TestStub;

EBox::Global::TestStub::fake();
EBox::Sudo::TestStub::fake();

use_ok('EBox::WebAdmin') or die;

my $webAdminMod = EBox::Global->modInstance('webadmin');
isa_ok($webAdminMod, 'EBox::WebAdmin');

my @resourceNames = ('foo/a', 'bar/a', 'foo/b');

is ($webAdminMod->_restrictedResourceExists($resourceNames[0]), 0, 'Resource not exists before adding');

lives_ok {
    $webAdminMod->setRestrictedResource($resourceNames[0], [ '192.168.45.2/32', '10.0.0.0/24' ]);
} 'Adding a correct restricted resource';

lives_ok {
    $webAdminMod->setRestrictedResource($resourceNames[0], [ '192.168.1.4/32' ]);
} 'Updating a correct restricted file';

lives_ok {
    $webAdminMod->setRestrictedResource($resourceNames[1], [ 'all', '102.1.2.3/32' ]);
} 'Adding an all allow restricted location';

is ($webAdminMod->_restrictedResourceExists($resourceNames[0]), 1, 'Resource exists after adding');

throws_ok {
    $webAdminMod->setRestrictedResource($resourceNames[2]);
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

throws_ok {
    $webAdminMod->setRestrictedResource($resourceNames[2], []);
} 'EBox::Exceptions::Internal', 'No given IP address';

throws_ok {
    $webAdminMod->setRestrictedResource($resourceNames[2], [ 'foobar', '10.0.0.2/24']);
} 'EBox::Exceptions::Internal', 'Deviant IP address';

cmp_deeply($webAdminMod->get_list('restricted_resources'),
           [ { allowedIPs => [ '192.168.1.4/32' ],
               name       => $resourceNames[0],
             },
             { allowedIPs => ['all'],
               name       => $resourceNames[1],
             }],
            'The additions and updates were done correctly');

throws_ok {
    $webAdminMod->delRestrictedResource();
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

lives_ok {
    foreach my $resourceName (@resourceNames[0 .. 1]) {
        $webAdminMod->delRestrictedResource($resourceName);
    }
} 'Deleting correct restricted resources';

is ($webAdminMod->_restrictedResourceExists($resourceNames[1]), 0, 'Resource not exists after deleting');

throws_ok {
    $webAdminMod->delRestrictedResource($resourceNames[2]);
} 'EBox::Exceptions::DataNotFound', 'Given resource name not found';

# Include related tests
my @includes = ( '/bin/true', '/bin/false' );
my @deviantIncludes = ( '/bin/dafdfa' );

# Nginx includes.
throws_ok {
    $webAdminMod->addNginxInclude();
} 'EBox::Exceptions::MissingArgument', 'No file to include';


lives_ok {
    $webAdminMod->addNginxInclude($_) foreach (@includes);
} 'Adding some includes';

cmp_deeply($webAdminMod->_nginxIncludes(), \@includes,
       'The two includes added');

lives_ok {
    $webAdminMod->addNginxInclude($_) foreach (@includes);
} 'Trying to add the same again';

cmp_deeply($webAdminMod->_nginxIncludes(), \@includes,
           'Only the two includes are there');

throws_ok {
    $webAdminMod->removeNginxInclude();
} 'EBox::Exceptions::MissingArgument', 'No file to exclude';

lives_ok {
    $webAdminMod->removeNginxInclude($deviantIncludes[0]);
} 'Trying to remove a no-included file does not trigger error';
cmp_deeply($webAdminMod->_nginxIncludes(), \@includes,
           'After the removal of a no-included file nothing is affected');

lives_ok {
    $webAdminMod->removeNginxInclude($_) foreach (@includes);
} 'Removing all the include files';

cmp_ok(@{$webAdminMod->_nginxIncludes()}, '==', 0,
       'Nothing has been left');

# Nginx server includes.
throws_ok {
    $webAdminMod->addNginxServer();
} 'EBox::Exceptions::MissingArgument', 'No server file to include';

lives_ok {
    $webAdminMod->addNginxServer($deviantIncludes[0]);
} 'Server file to include does not exits but it doesn\'t break';

lives_ok {
    $webAdminMod->removeNginxServer($deviantIncludes[0]);
} 'Server file to remove does not exits but it doesn\'t break';

lives_ok {
    $webAdminMod->addNginxServer($_) foreach (@includes);
} 'Adding some server includes';

cmp_deeply($webAdminMod->_nginxServers(), \@includes,
       'The two server includes are added');

lives_ok {
    $webAdminMod->addNginxServer($_) foreach (@includes);
} 'Trying to add the same again';

cmp_deeply($webAdminMod->_nginxServers(), \@includes,
           'Only the two server includes are there');

throws_ok {
    $webAdminMod->removeNginxServer();
} 'EBox::Exceptions::MissingArgument', 'No server file to exclude';

lives_ok {
    $webAdminMod->removeNginxServer($deviantIncludes[0]);
} 'Trying to remove a no-included server file does not trigger error';
cmp_deeply($webAdminMod->_nginxServers(), \@includes,
           'After the removal of a no-included server file nothing is affected');

lives_ok {
    $webAdminMod->removeNginxServer($_) foreach (@includes);
} 'Removing all the include server files';

cmp_ok(@{$webAdminMod->_nginxServers()}, '==', 0,
       'Nothing has been left');
1;
