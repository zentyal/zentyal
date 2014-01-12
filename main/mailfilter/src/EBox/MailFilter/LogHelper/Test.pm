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

package EBox::MailFilter::LogHelper::Test;

use base 'EBox::Test::Class';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;
use Test::MockObject;

use Data::Dumper;

use EBox::MailFilter::LogHelper;

use constant SMTP_FILTER_TABLE => 'mailfilter_smtp';
use constant MAIL_LOG => '/var/log/mail.log';

#  this class can be split in one specif class and a base tst class for
# loghelper test classess.

sub dumpInsertedData
{
    return 0;
}

my $_tablename;

sub tablename
{
    return $_tablename;
}

sub setTableName
{
  my ($name) = @_;
  $_tablename = $name;

}

my %_notNullsByTable = (
                        'mailfilter_smtp' => [ qw( timestamp event action
                                                 from_address to_address )
                                             ],
                       );

sub tableNotNullFields
{
  my ($self, $table) = @_;
  if (not exists  $_notNullsByTable{$table}) {
    die "Unknown table $table";
  }

  return $_notNullsByTable{$table};
}

sub logHelper
{
    return new EBox::MailFilter::LogHelper();
}

sub newFakeDBEngine
{
    my $dbengine = Test::MockObject->new();
    $dbengine->mock('insert' => sub {
                        my ($self, $table, $data) = @_;
                        $self->{insertedTable} = $table;
                        $self->{insertedData}  = $data;
                    }
                   );
    return $dbengine;
}

sub checkInsert
{
    my ($self, $dbengine, $expectedData) = @_;

    my $insertCalls = 0;
    while (my $calledMethod = $dbengine->next_call()) {
        if ($calledMethod eq 'insert') {
            $insertCalls +=1;
        }
    }

    is $insertCalls, 1, 'Checking  insert was called and was called only one time';

    my $table = delete $dbengine->{insertedTable};
    is $table, $self->tablename,
        'checking that the insert was made in the appropiate log table';

    my $data = delete $dbengine->{insertedData};
    if ($self->dumpInsertedData()) {
        diag "Inserted Data:\n" . Dumper $data;
    }

    my @notNullFields = @{ $self->tableNotNullFields($table)  };
    my $failed = 0;
    foreach my $field (@notNullFields) {
        if ((not exists $data->{$field}) or (not defined $data->{$field})) {
            fail "NOT NULL field $field was NULL";
            $failed = 1;
            last;
        }
    }

    if (not $failed) {
        pass "All NOT-NULL fields don't contain NULLs";
    }

    if ($expectedData) {
        is_deeply $data, $expectedData,
            'checking if inserted data is correct';
    }

    $dbengine->clear();
}

sub testProcessLine
{
    my ($self, $tablename, $file, $cases_r) = @_;

    setTableName($tablename);

    my $logHelper = $self->logHelper();

    foreach my $case (@{ $cases_r }) {
        diag $case->{name};

        my @lines = @{ $case->{lines} };

        my $dbEngine = $self->newFakeDBEngine();
        lives_ok {
            foreach my $line (@lines) {
                $logHelper->processLine($file, $line, $dbEngine);
            }
        } 'processing lines';

        $self->checkInsert($dbEngine, $case->{expectedData});
    }

}

sub smtpFilterLogTest : Test(65)
{
    my ($self) = @_;

    my $year = _currentYear();
    my @cases = (
                 {
                  name => 'Spam detected, pass policy',
                  lines => [
                            'Aug 27 04:57:10 intrepid amavis[11173]: (11173-01) Passed SPAM, <spam@zentyal.org> -> <macaco@monos.org>, Hits: 4.637, tag=0, tag2=2, kill=2, queued_as: 7D978307BD, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Passed',
                                   'spam_hits' => '4.637',
                                   timestamp => "$year-08-27 04:57:10",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Spam detected, reject policy',
                  lines => [
'Aug 27 05:00:30 intrepid amavis[11802]: (11802-02) Blocked SPAM, <spam@zentyal.org> -> <macaco@monos.org>, Hits: 4.736, tag=0, tag2=2, kill=2, L/Y/Y/Y',
                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Blocked',
                                   'spam_hits' => '4.736',
                                   timestamp => "$year-08-27 05:00:30",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Spam detected, bounce policy',
                  lines => [
                            'Aug 27 05:03:30 intrepid amavis[12473]: (12473-01) Blocked SPAM, <spam@zentyal.org> -> <macaco@monos.org>, Hits: 4.906, tag=0, tag2=2, kill=2, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Blocked',
                                   'spam_hits' => '4.906',
                                   timestamp => "$year-08-27 05:03:30",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Virus detected, discard policy',
                  lines => [
                            'Aug 27 05:32:12 intrepid amavis[13093]: (13093-02) Blocked INFECTED (Eicar-Test-Signature), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0',

                           ],
                  expectedData => {
                                   event => 'INFECTED',
                                   action => 'Blocked',
                                   timestamp => "$year-08-27 05:32:12",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Virus detected, pass policy',
                  lines => [
                            'Aug 27 05:35:12 intrepid amavis[14032]: (14032-01) Passed INFECTED (Eicar-Test-Signature), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: 684C4307BD, L/Y/0/0',
                           ],
                  expectedData => {
                                   event => 'INFECTED',
                                   action => 'Passed',
                                   timestamp => "$year-08-27 05:35:12",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden MIME type , bounce policy',
                  lines => [
                            'Aug 27 06:03:13 intrepid amavis[16115]: (16115-01) Blocked BANNED (multipart/mixed | application/x-zip,.zip,putty.zip | .exe,.exe-ms,PAGEANT.EXE), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0',

                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Blocked',
                                   timestamp => "$year-08-27 06:03:13",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden MIME type , pass policy',
                  lines => [
                            'Aug 27 06:09:44 intrepid amavis[17590]: (17590-01) Passed BANNED (multipart/mixed | application/x-zip,.zip,putty.zip | .exe,.exe-ms,PAGEANT.EXE), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: B8797307BD, L/Y/0/0',

                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Passed',
                                   timestamp => "$year-08-27 06:09:44",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden file extension, bounce policy',
                  lines => [
                            'Aug 27 06:00:52 intrepid amavis[16114]: (16114-01) Blocked BANNED (multipart/mixed | application/x-msdos-program,.exe,.exe-ms,putty.exe), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Blocked',
                                   timestamp => "$year-08-27 06:00:52",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden file extension, pass policy',
                  lines => [
                            'Aug 27 06:10:37 intrepid amavis[17591]: (17591-01) Passed BANNED (multipart/mixed | application/x-msdos-program,.exe,.exe-ms,putty.exe), <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: 89228307BD, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Passed',
                                   timestamp => "$year-08-27 06:10:37",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Sender blacklisted',
                  lines => [
'Aug 27 06:16:53 intrepid amavis[18339]: (18339-01) Blocked SPAM, <spam@zentyal.org> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'BLACKLISTED',
                                   action => 'Blocked',
                                   timestamp => "$year-08-27 06:16:53",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Bad header with pass policy',
                  lines => [
                            'Aug 27 06:38:30 intrepid amavis[21050]: (21050-02) Passed BAD-HEADER, <bb@gm.com> -> <macaco@monos.org>, Hits: 12.019, tag=0, tag2=20, kill=20, queued_as: F2DFE30045, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'BAD-HEADER',
                                   action => 'Passed',
                                   timestamp => "$year-08-27 06:38:30",
                                   from_address => 'bb@gm.com',
                                   to_address   => 'macaco@monos.org',
                                   'spam_hits'  => 12.019,
                                  },
                 },

                 {
                  name => 'Bad header with pass policy',
                  lines => [
                            'Aug 27 06:42:59 intrepid amavis[21882]: (21882-01) Blocked BAD-HEADER, <c@aa.com> -> <macaco@monos.org>, Hits: 8.92, tag=0, tag2=20, kill=20, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'BAD-HEADER',
                                   action => 'Blocked',
                                   timestamp => "$year-08-27 06:42:59",
                                   from_address => 'c@aa.com',
                                   to_address   => 'macaco@monos.org',
                                   'spam_hits' => 8.92,
                                  },
                 },

                 {
                  name => 'Clean message',
                  lines => [
                            'Jul 29 06:44:16 intrepid amavis[25342]: (25342-04) Passed CLEAN, <spam@zentyal.org> -> <macaco@monos.org>, Hits: 3.904, tag=0, tag2=5, kill=5, queued_as: 96A4530845, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'CLEAN',
                                   action => 'Passed',
                                   timestamp => "$year-07-29 06:44:16",
                                   from_address => 'spam@zentyal.org',
                                   to_address   => 'macaco@monos.org',
                                   'spam_hits' => 3.904,
                                  },
                 },

                );

    $self->testProcessLine(SMTP_FILTER_TABLE, MAIL_LOG, \@cases);
}

sub _currentYear
{
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
    $year += 1900;
    return $year;
}

1;
