package EBox::MailFilter::LogHelper::Test;

use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;
use Test::MockObject;

use Data::Dumper;

use lib '../../..';

use EBox::MailFilter::LogHelper;

use constant SMTP_FILTER_TABLE => 'message_filter';
use constant MAIL_LOG => '/var/log/mail.log';


use constant POP_PROXY_TABLE   => 'pop_proxy_filter';
use constant SYS_LOG => '/var/log/syslog';


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
                        'message_filter' => [ qw( event action date
                                                 from_address to_address)
                                             ],
                        'pop_proxy_filter'  => [ qw(date event  mails 
                                                 clean virus spam clientConn)
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

    my @cases = (
                 {
                  name => 'Spam detected, pass policy',
                  lines => [
                            'Aug 27 04:57:10 intrepid amavis[11173]: (11173-01) Passed SPAM, <spam@warp.es> -> <macaco@monos.org>, Hits: 4.637, tag=0, tag2=2, kill=2, queued_as: 7D978307BD, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Passed',
                                   'spam_hits' => '4.637',
                                   date => '2008-Aug-27 04:57:10',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Spam detected, reject policy',
                  lines => [
'Aug 27 05:00:30 intrepid amavis[11802]: (11802-02) Blocked SPAM, <spam@warp.es> -> <macaco@monos.org>, Hits: 4.736, tag=0, tag2=2, kill=2, L/Y/Y/Y',
                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Blocked',
                                   'spam_hits' => '4.736',
                                   date => '2008-Aug-27 05:00:30',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Spam detected, bounce policy',
                  lines => [
                            'Aug 27 05:03:30 intrepid amavis[12473]: (12473-01) Blocked SPAM, <spam@warp.es> -> <macaco@monos.org>, Hits: 4.906, tag=0, tag2=2, kill=2, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'SPAM',
                                   action => 'Blocked',
                                   'spam_hits' => '4.906',
                                   date => '2008-Aug-27 05:03:30',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },


                 {
                  name => 'Virus detected, discard policy',
                  lines => [
                            'Aug 27 05:32:12 intrepid amavis[13093]: (13093-02) Blocked INFECTED (Eicar-Test-Signature), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0',
                            
                           ],
                  expectedData => {
                                   event => 'INFECTED',
                                   action => 'Blocked',
                                   date => '2008-Aug-27 05:32:12',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },


                 {
                  name => 'Virus detected, pass policy',
                  lines => [
                            'Aug 27 05:35:12 intrepid amavis[14032]: (14032-01) Passed INFECTED (Eicar-Test-Signature), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: 684C4307BD, L/Y/0/0',
                           ],
                  expectedData => {
                                   event => 'INFECTED',
                                   action => 'Passed',
                                   date => '2008-Aug-27 05:35:12',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden MIME type , bounce policy',
                  lines => [
                            'Aug 27 06:03:13 intrepid amavis[16115]: (16115-01) Blocked BANNED (multipart/mixed | application/x-zip,.zip,putty.zip | .exe,.exe-ms,PAGEANT.EXE), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0',
                            
                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Blocked',
                                   date => '2008-Aug-27 06:03:13',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden MIME type , pass policy',
                  lines => [
                            'Aug 27 06:09:44 intrepid amavis[17590]: (17590-01) Passed BANNED (multipart/mixed | application/x-zip,.zip,putty.zip | .exe,.exe-ms,PAGEANT.EXE), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: B8797307BD, L/Y/0/0',
                            
                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Passed',
                                   date => '2008-Aug-27 06:09:44',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden file extension, bounce policy',
                  lines => [
                            'Aug 27 06:00:52 intrepid amavis[16114]: (16114-01) Blocked BANNED (multipart/mixed | application/x-msdos-program,.exe,.exe-ms,putty.exe), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/0/0'

                            
                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Blocked',
                                   date => '2008-Aug-27 06:00:52',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Forbidden file extension, pass policy',
                  lines => [
                            'Aug 27 06:10:37 intrepid amavis[17591]: (17591-01) Passed BANNED (multipart/mixed | application/x-msdos-program,.exe,.exe-ms,putty.exe), <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, queued_as: 89228307BD, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'BANNED',
                                   action => 'Passed',
                                   date => '2008-Aug-27 06:10:37',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                  },
                 },

                 {
                  name => 'Sender blacklisted',
                  lines => [
'Aug 27 06:16:53 intrepid amavis[18339]: (18339-01) Blocked SPAM, <spam@warp.es> -> <macaco@monos.org>, Hits: -, tag=0, tag2=2, kill=2, L/Y/Y/Y'

                           ],
                  expectedData => {
                                   event => 'BLACKLISTED',
                                   action => 'Blocked',
                                   date => '2008-Aug-27 06:16:53',
                                   from_address => 'spam@warp.es',
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
                                   date => '2008-Aug-27 06:38:30',
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
                                   date => '2008-Aug-27 06:42:59',
                                   from_address => 'c@aa.com',
                                   to_address   => 'macaco@monos.org',
                                   'spam_hits' => 8.92,
                                  },
                 },

                 {
                  name => 'Clean message',
                  lines => [
                            'Jul 29 06:44:16 intrepid amavis[25342]: (25342-04) Passed CLEAN, <spam@warp.es> -> <macaco@monos.org>, Hits: 3.904, tag=0, tag2=5, kill=5, queued_as: 96A4530845, L/Y/0/0'

                           ],
                  expectedData => {
                                   event => 'CLEAN',
                                   action => 'Passed',
                                   date => '2008-Jul-29 06:44:16',
                                   from_address => 'spam@warp.es',
                                   to_address   => 'macaco@monos.org',
                                   'spam_hits' => 3.904,
                                  },
                 },




                );


    $self->testProcessLine(SMTP_FILTER_TABLE, MAIL_LOG, \@cases);
}



sub popProxyLogTest : Test(25)
{
  my ($self) = @_;

  my @cases = (
               {
                name => 'zero mails',
                lines => [
q{Oct 30 11:26:46 ebox011101 p3scan[25124]: Connection from 192.168.9.1:48999 },
q{Oct 30 11:26:46 ebox011101 p3scan[25124]: Real-server adress is 82.194.70.220:110 },
q{Oct 30 11:26:46 ebox011101 p3scan[25124]: USER 'poptest@example.com' },
q{Oct 30 11:26:46 ebox011101 p3scan[25124]: Session done (Clean Exit). Mails: 0 Bytes: 0 },
                         ],
        expectedData => {
                      event => 'pop3_fetch_ok',
                      address => 'poptest@example.com',

                      mails  => 0,
                      clean  => 0,
                      virus  => 0,
                      spam   => 0,
                      
                      clientConn => '192.168.9.1',

                      
                      date => '2008-Oct-30 11:26:46',
                     },
               },
               {
                name => 'only one mail',
                lines => [
q{Oct 30 07:56:53 ebox011101 p3scan[15225]: Selected scannertype: basic (Basic file invocation scanner) },
q{Oct 30 07:56:53 ebox011101 p3scan[15225]: Listen now on 0.0.0.0:8110 },
q{Oct 30 11:07:15 ebox011101 p3scan[15226]: signalled, doing cleanup },
q{Oct 30 11:07:15 ebox011101 p3scan[15226]: P3Scan terminates now },
q{Oct 30 11:25:31 ebox011101 p3scan[25070]: Connection from 192.168.9.1:48994 },
q{Oct 30 11:25:31 ebox011101 p3scan[25070]: Real-server adress is 82.194.70.220:110 },
q{Oct 30 11:25:31 ebox011101 p3scan[25070]: USER 'poptest@example.com' },
q{Oct 30 11:25:32 ebox011101 spamd[24318]: spamd: setuid to p3scan succeeded },
q{Oct 30 11:25:32 ebox011101 spamd[24318]: spamd: processing message <48569c20811060706u205207b3s71dc7ab7eaaa23b7@mail.gmail.com> for p3scan:118 },
q{Oct 30 11:25:33 ebox011101 spamd[24318]: spamd: clean message (0.0/5.0) for p3scan:118 in 0.8 seconds, 46836 bytes. },
q{Oct 30 11:25:33 ebox011101 spamd[24318]: spamd: result: . 0 - HTML_MESSAGE,SPF_PASS scantime=0.8,size=46836,user=p3scan,uid=118,required_score=5.0,rhost=localhost,raddr=127.0.0.1,rport=60954,mid=<48569c20811060706u205207b3s71dc7ab7eaaa23b7@mail.gmail.com>,autolearn=no },
q{Oct 30 11:25:33 ebox011101 p3scan[25070]: Session done (Clean Exit). Mails: 1 Bytes: 44334},
                         ],
        expectedData => {
                      event => 'pop3_fetch_ok',
                      address => 'poptest@example.com',

                      mails  => 1,
                      clean  => 1,
                      virus  => 0,
                      spam   => 0,
                      
                      clientConn => '192.168.9.1',

                      
                      date => '2008-Oct-30 11:25:33',
                     },
               },

               {
                name => 'one clean and one virus',
                lines => [
q{Oct 30 11:07:15 ebox011101 p3scan[24288]: P3Scan Version 2.1 },
q{Oct 30 11:07:15 ebox011101 p3scan[24288]: Selected scannertype: basic (Basic file invocation scanner) },
q{Oct 30 11:07:15 ebox011101 p3scan[24288]: Listen now on 0.0.0.0:8110 },
q{Oct 30 11:24:21 ebox011101 p3scan[24992]: Connection from 192.168.9.1:48987 },
q{Oct 30 11:24:21 ebox011101 p3scan[24992]: Real-server adress is 82.194.70.220:110 },
q{Oct 30 11:24:21 ebox011101 p3scan[24992]: USER 'poptest@example.com' },
q{Oct 30 11:24:23 ebox011101 spamd[24318]: spamd: setuid to p3scan succeeded },
q{Oct 30 11:24:23 ebox011101 spamd[24318]: spamd: processing message <48569c20811060650t4ec1866cu1fd66118987e1745@mail.gmail.com> for p3scan:118 },
q{Oct 30 11:24:25 ebox011101 spamd[24318]: spamd: clean message (0.0/5.0) for p3scan:118 in 1.8 seconds, 46009 bytes. },
q{Oct 30 11:24:25 ebox011101 spamd[24318]: spamd: result: . 0 - HTML_MESSAGE,SPF_PASS scantime=1.8,size=46009,user=p3scan,uid=118,required_score=5.0,rhost=localhost,raddr=127.0.0.1,rport=60952,mid=<48569c20811060650t4ec1866cu1fd66118987e1745@mail.gmail.com>,autolearn=no },
q{Oct 30 11:24:25 ebox011101 p3scan[24992]: '/var/spool/p3scan/children/24992/p3scan.ufuAdZ' contains a virus (Eicar-Test-Signature)! },
q{Oct 30 11:24:25 ebox011101 p3scan[24992]: Session done (Clean Exit). Mails: 2 Bytes: 44471 },
                         ],
        expectedData => {
                      event => 'pop3_fetch_ok',
                      address => 'poptest@example.com',

                      mails  => 2,
                      clean  => 1,
                      virus  => 1,
                      spam   => 0,
                      
                      clientConn => '192.168.9.1',

                      
                      date => '2008-Oct-30 11:24:25',
                     },
               },

               {
                name => 'one spam',
                lines => [
q{Oct 30 11:31:33 ebox011101 p3scan[26477]: Listen now on 0.0.0.0:8110 },
q{Oct 30 11:34:30 ebox011101 p3scan[26596]: Connection from 192.168.9.1:40087 },
q{Oct 30 11:34:30 ebox011101 p3scan[26596]: Real-server adress is 82.194.70.220:110 },
q{Oct 30 11:34:30 ebox011101 p3scan[26596]: USER 'poptest@example.com' },
q{Oct 30 11:34:30 ebox011101 spamd[26486]: spamd: setuid to p3scan succeeded },
q{Oct 30 11:34:30 ebox011101 spamd[26486]: spamd: processing message <48569c20811060715o430d34b7i2b165ce22d8d605a@mail.gmail.com> for p3scan:118 },
q{Oct 30 11:34:31 ebox011101 spamd[26486]: spamd: identified spam (0.3/0.1) for p3scan:118 in 0.7 seconds, 3029 bytes. },
q{Oct 30 11:34:31 ebox011101 spamd[26486]: spamd: result: Y 0 - AWL,DRUGS_ERECTILE,HTML_MESSAGE,SPF_PASS scantime=0.7,size=3029,user=p3scan,uid=118,required_score=0.1,rhost=localhost,raddr=127.0.0.1,rport=37570,mid=<48569c20811060715o430d34b7i2b165ce22d8d605a@mail.gmail.com>,autolearn=no },
q{Oct 30 11:34:31 ebox011101 p3scan[26596]: Session done (Clean Exit). Mails: 1 Bytes: 5257 },

                         ],
        expectedData => {
                      event => 'pop3_fetch_ok',
                      address => 'poptest@example.com',

                      mails  => 1,
                      clean  => 0,
                      virus  => 0,
                      spam   => 1,
                      
                      clientConn => '192.168.9.1',

                      
                      date => '2008-Oct-30 11:34:31',
                     },
               },

               {
                name => 'failed',
                lines => [
'Oct 30 11:27:55 ebox011101 p3scan[25162]: Connection from 192.168.9.1:49254 ',
'Oct 30 11:27:55 ebox011101 p3scan[25162]: Real-server adress is 192.168.9.149:110 ',
'Oct 30 11:27:55 ebox011101 p3scan[25162]: Cannot connect to real-server ',
'Oct 30 11:27:55 ebox011101 p3scan[25162]: Session done (Critial abort). Mails: 0 Bytes: 0 ',
                         ],
        expectedData => {
                      event => 'pop3_fetch_failed',
                      address => undef,

                      mails  => 0,
                      clean  => 0,
                      virus  => 0,
                      spam   => 0,
                      
                      clientConn => '192.168.9.1',
                      
                      date => '2008-Oct-30 11:27:55',
                     },
               },
              );

  $self->testProcessLine(POP_PROXY_TABLE, SYS_LOG, \@cases);
}

1;
