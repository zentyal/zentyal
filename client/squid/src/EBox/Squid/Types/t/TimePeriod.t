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



#

use strict;
use warnings;

use Test::More tests => 43;
use Test::Exception;


use EBox::TestStubs;

use lib '../../../..';

use EBox::Squid::Types::TimePeriod;



EBox::TestStubs::activateTestStubs();

EBox::TestStubs::fakeEBoxModule(name => 'fakemodule');


my $gconfmodule  = EBox::Global->modInstance('fakemodule');
my $dir          = 'storeDir';

my $timePeriod;

 lives_ok {
     $timePeriod = new EBox::Squid::Types::TimePeriod(
                           fieldName => 'timePeriod',
                           printableName =>    'Time period' ,
                           editable => 1,
                          ),
} 'Creating new TimePeriod instance';

ok  $timePeriod->monday();
is $timePeriod->value(), 'MTWHFAS'; 
ok $timePeriod->isAllTime();


_setValue($timePeriod, '10:00-11:00 T');

is $timePeriod->from(), '10:00';
is $timePeriod->to(), '11:00';
ok not $timePeriod->monday();
ok (not $timePeriod->isAllTime());

_setValue($timePeriod, 'MS');
is $timePeriod->from(), undef;
is $timePeriod->to(),   undef;
ok  $timePeriod->monday();
ok not $timePeriod->tuesday();
ok not $timePeriod->saturday();
ok  $timePeriod->sunday();

_setValue($timePeriod, '11:00-11:21 TA');
is $timePeriod->from(), '11:00';
is $timePeriod->to(),   '11:21';
ok  not $timePeriod->monday();
ok $timePeriod->tuesday();
ok $timePeriod->saturday();
ok not $timePeriod->sunday();

_setValue($timePeriod, '10-11:00 T', '10:00-11:00 T');

is $timePeriod->from(), '10:00';
is $timePeriod->to(), '11:00';
ok not $timePeriod->monday();

_setValue($timePeriod, '9-12 F', '9:00-12:00 F');

is $timePeriod->from(), '9:00';
is $timePeriod->to(), '12:00';
ok not $timePeriod->monday();

_setValue($timePeriod, '11-11:21 TA', '11:00-11:21 TA');
is $timePeriod->from(), '11:00';
is $timePeriod->to(),   '11:21';
ok  not $timePeriod->monday();
ok $timePeriod->tuesday();
ok $timePeriod->saturday();
ok not $timePeriod->sunday();



my @badValues = (
                    '',
                     '10:00 F',
                     '10:00- F',
                      '13:00-10:00 F',
                       '01:21-31:11 F',
                   );
foreach my $value (@badValues) {
    dies_ok {
        $timePeriod->setValue($value);
    } "trying bad value $value";
}



sub _setValue
{
    my ($timePeriod, $value, $expectedValue) = @_;
    defined $expectedValue or
        $expectedValue = $value;

    $timePeriod->setValue($value);
    $timePeriod->storeInGConf($gconfmodule, $dir);
    $timePeriod = _newTimePeriod();
    $timePeriod->restoreFromHash($gconfmodule->hash_from_dir($dir));


    is $timePeriod->value(), $expectedValue;
}

sub _newTimePeriod
{
    return new EBox::Squid::Types::TimePeriod(
                                              fieldName => 'timePeriod',
                                              printableName =>    'Time period' ,
                                              editable => 1,
                                             );

}


1;
