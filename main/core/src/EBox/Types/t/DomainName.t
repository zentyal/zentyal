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
use strict;
use warnings;

use Test::More  tests => 5;

use lib '../../..';

use EBox::Types::TestHelper;
use EBox::Types::DomainName;

sub creationTest
{
    my @validDomainNames = (
                            'monos.org',
                            'foo.zentyal.com',
                            '347.net',
                           );

    my @invalidDomainNames = (
                              '32.21.12.12',
                              'domi$$nio.biz',
                             );


    foreach my $domain (@validDomainNames) {
        EBox::Types::TestHelper::createOk(
                                    'EBox::Types::DomainName',
                                    fieldName => 'test',
                                    value => $domain,
                                    "Checking instance creation with valid domain name $domain"
                                   );

    }

    foreach my $domain (@invalidDomainNames) {
        EBox::Types::TestHelper::createFail(
                                      'EBox::Types::DomainName',
                                      fieldName => 'test',
                                      printableName => 'test',
                                      value         => $domain,
                                      "Checking instance creation raises error when called with invalid domain name $domain"
                                     );
    }

}

EBox::Types::TestHelper::setupFakes();
creationTest();

1;
