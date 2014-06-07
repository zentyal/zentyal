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

use Test::More tests => 10;
use Test::Exception;

use lib '../../..';
use EBox::Samba::Group;
use EBox::TestStub;


sub testCheckAccountName
{
    my $maxLen = 20;
    my @valid = (
        'user1',
        'user espacio',
        'user-slash_',
       );
    push @valid, 'v' x  $maxLen;
    my @invalid = (
        '3232', # groups cannto be a number
        'enddot.',
        '-startslash',
        '. ',
        'problematic&characters',
       );
    push @invalid, 'l' x ($maxLen+1);
    foreach my $validName (@valid) {
        lives_ok {
            EBox::Samba::Group->_checkAccountName($validName, $maxLen);
        } "Checking that $validName is a correct group account name";
    }
    foreach my $invalidName (@invalid) {
        dies_ok {
            EBox::Samba::Group->_checkAccountName($invalidName, $maxLen);
        } "Checking that $invalidName is raises exception as invalid group account name";
    }
}

EBox::TestStub::fake();
testCheckAccountName();

1;
