# Copyright (C) 2009 EBox Technologies S.L.
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

use Test::More qw(no_plan);
use Test::Exception;
use EBox::Sudo;
use File::Slurp;
use Data::Dumper;


use lib '../..';
use EBox::MailQueue;

sub testMailQueueList
{
    my $output;
    lives_ok {
        $output = EBox::MailQueue->mailQueueList();
    } 'getting mail queue';


    my @fields = qw(msg qid sender atime recipients size);

    my $allFieldsOk = 1;
    foreach my $msgInfo (@{ $output }) {
        foreach my $field (@fields) {
            if (not exists $msgInfo->{$field}) {
                fail "No field $field found in msginfo" . Dumper($output);

                $allFieldsOk = 1;
            }
        }
    }

    ok $allFieldsOk, 'checking for the presence of fields in mail queue list';

}



{
    no warnings 'redefine';

   sub EBox::Sudo::root
   {
       my @mailqOutput = File::Slurp::read_file('testdata/mailqoutput.txt');
       return \@mailqOutput;
   }
}


testMailQueueList();
1;
