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

use Test::More tests => 10;

use EBox::TestStubs;


use lib '../../../..';

use EBox::Types::Test;
use EBox::MailFilter::Types::AntispamThreshold;

EBox::TestStubs::activateTestStubs();

my @validCases = (
                  [
                   value => 0,
                  ],
                  [
                   value => 10,
                  ],
                  [
                   value => -10,
                  ],
                  [
                   value => 4.5,
                  ],
                  [
                   value => -0.23,
                  ],
                  # positive value and positive argument
                  [
                   positive => 1,
                   value => 1,
                  ],

                  
                 );


my @deviantCases = (
                    # bad values when positive option
                    [
                     positive => 1,
                     value => -1,
                    ],
                    [
                     positive => 1,
                     value => 0,
                    ],
                    # out of bounds values
                    [
                     value => 5000,
                    ],
                    [
                     value => -5000
                    ],
                   );




foreach my $case_r (@validCases) {
    my @params = @{ $case_r };
    EBox::Types::Test::createOk(
                                'EBox::MailFilter::Types::AntispamThreshold',
                                fieldName => 'test',
                                @params,
                                "Checking instance creation with valid parameters and value"
                               );

}

foreach my $case_r (@deviantCases) {
    my @params = @{ $case_r };
    EBox::Types::Test::createFail(
                                  'EBox::MailFilter::Types::AntispamThreshold',
                                  @params,
"Checking instance creation raises error when called with invalid parameters and value"
                                 );
}






1;
