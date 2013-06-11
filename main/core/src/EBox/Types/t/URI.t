# Copyright (C) 2013 Zentyal S.L.
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

use Test::Exception;
use Test::More tests => 12;

use EBox::Types::TestHelper;
use EBox::Types::URI;

sub testValidURI
{
    my @validURIs = (
        'file:///foo/bar',
        'https://foo.com',
        'http://foo.bar:8303',
        'ftp://lalala.com',
       );

    my @invalidURIs = (
        '32.21.12.12',
        'domi$$nio.biz',
       );

    my @validSchemeOnlyURIs = (
        'https://modest.mouse',
        'http://bukowski.com:882/goodnews',
        );

    my @invalidSchemeOnlyURIs = (
        'against-me',
        'ftp://tsr.rules',
        'file:///four/bloc/party',
       );

    throws_ok {
        new EBox::Types::URI(
            fieldName => 'test',
            printableName => 'test',
            value         => 'file:///foo',
            validSchemes  => { 'invalid' => 'schemearg' },
           );
    } 'EBox::Exceptions::InvalidType',
      'Invalid type for validSchemes argument';

    foreach my $uri (@validURIs) {
        EBox::Types::TestHelper::createOk(
            'EBox::Types::URI',
            fieldName => 'test',
            value => $uri,
            "Checking instance creation with valid URI $uri"
           );
    }

    foreach my $uri (@invalidURIs) {
        EBox::Types::TestHelper::createFail(
            'EBox::Types::URI',
            fieldName => 'test',
            printableName => 'test',
            value         => $uri,
            "Checking instance creation raises error when called with invalid URI $uri"
           );
    }


    foreach my $uri (@validSchemeOnlyURIs) {
        EBox::Types::TestHelper::createOk(
            'EBox::Types::URI',
            fieldName => 'test',
            value => $uri,
            validSchemes => [ 'http', 'https' ],
            "Checking instance creation with valid URI $uri only for a set of schemes"
           );
    }

    foreach my $uri (@invalidSchemeOnlyURIs) {
        EBox::Types::TestHelper::createFail(
            'EBox::Types::URI',
            fieldName => 'test',
            printableName => 'test',
            value         => $uri,
            validSchemes => [ 'http', 'https' ],
            "Checking instance creation raises error when called with invalid URI $uri only for a set of schemes"
           );
    }
}

EBox::Types::TestHelper::setupFakes();
testValidURI();

1;
