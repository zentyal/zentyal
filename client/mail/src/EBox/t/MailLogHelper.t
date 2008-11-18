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

use lib '../..';

use EBox::MailLogHelper;

use Test::More tests => 24;
use Test::MockObject;
use Test::Exception;

use Data::Dumper;

my $dumpInsertedData = 0;

use constant TABLENAME => "message";

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
    my ($dbengine, $expectedData) = @_;

    my $table = delete $dbengine->{insertedTable};
    is $table, TABLENAME,
        'checking that the insert was made in the mail log table';
    
    my $data = delete $dbengine->{insertedData};
    if ($dumpInsertedData) {
        diag "Inserted Data:\n" . Dumper $data;
    }

    my @notNullFields = qw(client_host_ip to_address status postfix_date);
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
}

my @cases = (
             {
              name => 'Message sent with both TSL and SASL active',
              lines => [
                        'Aug 25 06:48:55 intrepid postfix/smtpd[32425]: connect from unknown[192.168.45.159]',
                        'Aug 25 06:48:55 intrepid postfix/smtpd[32425]: setting up TLS connection from unknown[192.168.45.159]',
                        'Aug 25 06:48:55 intrepid postfix/smtpd[32425]: Anonymous TLS connection established from unknown[192.168.45.159]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
                        'Aug 25 06:48:55 intrepid postfix/smtpd[32425]: 44D533084A: client=unknown[192.168.45.159], sasl_method=PLAIN, sasl_username=macaco@monos.org',
                        'Aug 25 06:48:55 intrepid postfix/cleanup[32428]: 44D533084A: message-id=<200808251310.27640.spam@warp.es>',
                        'Aug 25 06:48:55 intrepid postfix/qmgr[3091]: 44D533084A: from=<spam@warp.es>, size=557, nrcpt=1 (queue active)',
                        'Aug 25 06:48:55 intrepid postfix/smtpd[32425]: disconnect from unknown[192.168.45.159]',
                        'Aug 25 06:48:55 intrepid postfix/virtual[32429]: 44D533084A: to=<macaco@monos.org>, relay=virtual, delay=0.11, delays=0.06/0.02/0/0.02, dsn=2.0.0, status=sent (delivered to maildir)',
                        'Aug 25 06:48:55 intrepid postfix/qmgr[3091]: 44D533084A: removed',

                       ],
              expectedData => {
                               from_address => 'spam@warp.es',
                               message_id => '200808251310.27640.spam@warp.es',
                               message_size => '557',
                               status => 'sent',
                               postfix_date => '2008-Aug-25 06:48:55',
                               event => 'msgsent',
                               message => 'delivered to maildir',
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'virtual, delay=0.11, delays=0.06/0.02/0/0.02',
                               client_host_ip => '192.168.45.159'
                              },
             },
             {
              name => 'Message sent with TSL but no  SASL',
              lines => [
                        'Aug 25 09:30:48 intrepid postfix/smtpd[22803]: connect from unknown[192.168.45.159]',
                        'Aug 25 09:30:48 intrepid postfix/smtpd[22803]: setting up TLS connection from unknown[192.168.45.159]',
                        'Aug 25 09:30:48 intrepid postfix/smtpd[22803]: Anonymous TLS connection established from unknown[192.168.45.159]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
                        'Aug 25 09:30:48 intrepid postfix/smtpd[22803]: B0E2D30845: client=unknown[192.168.45.159]',
                        'Aug 25 09:30:48 intrepid postfix/cleanup[22830]: B0E2D30845: message-id=<200808251653.45100.spam@warp.es>',
                        'Aug 25 09:30:48 intrepid postfix/qmgr[3208]: B0E2D30845: from=<spam@warp.es>, size=556, nrcpt=1 (queue active)',
                        'Aug 25 09:30:48 intrepid postfix/smtpd[22803]: disconnect from unknown[192.168.45.159]',
                        'Aug 25 09:30:48 intrepid postfix/virtual[22855]: B0E2D30845: to=<macaco@monos.org>, relay=virtual, delay=0.08, delays=0.04/0/0/0.04, dsn=2.0.0, status=sent (delivered to maildir)',
                        'Aug 25 09:30:48 intrepid postfix/qmgr[3208]: B0E2D30845: removed',
                       ],
              expectedData =>  {
                               from_address => 'spam@warp.es',
                               message_id => '200808251653.45100.spam@warp.es',
                               message_size => '556',
                               status => 'sent',
                               postfix_date => '2008-Aug-25 09:30:48',
                               event => 'msgsent',
                               message => 'delivered to maildir',
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'virtual, delay=0.08, delays=0.04/0/0/0.04',
                               client_host_ip => '192.168.45.159'
                              },

             },
             {
              name => 'Message sent without TSL or SASL',
                 lines => [
                           'Aug 25 09:41:13 intrepid postfix/smtpd[11871]: connect from unknown[192.168.45.159]',
                           'Aug 25 09:41:13 intrepid postfix/smtpd[11871]: 3BA2C3084A: client=unknown[192.168.45.159]',
                           'Aug 25 09:41:13 intrepid postfix/cleanup[13077]: 3BA2C3084A: message-id=<200808251704.09656.spam@warp.es>',
                           'Aug 25 09:41:13 intrepid postfix/qmgr[3684]: 3BA2C3084A: from=<spam@warp.es>, size=555, nrcpt=1 (queue active)',
                           'Aug 25 09:41:13 intrepid postfix/smtpd[11871]: disconnect from unknown[192.168.45.159]',
                           'Aug 25 09:41:13 intrepid postfix/virtual[13079]: 3BA2C3084A: to=<macaco@monos.org>, relay=virtual, delay=0.13, delays=0.09/0/0/0.04, dsn=2.0.0, status=sent (delivered to maildir)',
                           'Aug 25 09:41:13 intrepid postfix/qmgr[3684]: 3BA2C3084A: removed',
                          ],
              expectedData =>  {
                               from_address => 'spam@warp.es',
                               message_id => '200808251704.09656.spam@warp.es',
                               message_size => '555',
                               status => 'sent',
                               postfix_date => '2008-Aug-25 09:41:13',
                               event => 'msgsent',
                               message => 'delivered to maildir',
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'virtual, delay=0.13, delays=0.09/0/0/0.04',
                               client_host_ip => '192.168.45.159'
                              },

             },
             
             {
              name => 'Message relayed trough external smarthost',
                 lines => [
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: connect from unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: 2AF6952626: client=unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/cleanup[32275]: 2AF6952626: message-id=<200811181139.13287.spam@warp.es>',
'Oct 30 11:00:07 ebox011101 postfix/qmgr[31065]: 2AF6952626: from=<spam@warp.es>, size=580, nrcpt=1 (queue active)',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: disconnect from unknown[192.168.9.1]',
'Oct 30 11:00:22 ebox011101 postfix/smtp[32362]: 2AF6952626: to=<jag@gmail.com>, relay=smtp.warp.es[82.194.70.220]:25, delay=15, delays=0.03/0/6.9/8.3, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 3F7CEBC608)',
'Oct 30 11:00:22 ebox011101 postfix/qmgr[31065]: 2AF6952626: removed',

                          ],
              expectedData =>  {
                               from_address => 'spam@warp.es',
                               message_id => '200811181139.13287.spam@warp.es',
                               message_size => '580',
                               status => 'sent',
                               postfix_date => '2008-Oct-30 11:00:22',
                               event => 'msgsent',
                               message => '250 2.0.0 Ok: queued as 3F7CEBC608',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => 'smtp.warp.es[82.194.70.220]:25, delay=15, delays=0.03/0/6.9/8.3',
                               client_host_ip => '192.168.9.1'
                              },

             },

             {
              name => 'Message relayed to unavailable external smarthost',
                 lines => [
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: connect from unknown[192.168.9.1]',
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 13:07:39 ebox011101 postfix/smtpd[16765]: 6E06752608: client=unknown[192.168.9.1]',
'Oct 30 13:07:39 ebox011101 postfix/cleanup[16769]: 6E06752608: message-id=<200811181346.45800.spam@warp.es>',
'Oct 30 13:07:39 ebox011101 postfix/qmgr[16604]: 6E06752608: from=<spam@warp.es>, size=580, nrcpt=1 (queue active)',
'Oct 30 13:07:39 ebox011101 postfix/smtpd[16765]: disconnect from unknown[192.168.9.1]',
'Oct 30 13:08:09 ebox011101 postfix/smtp[16770]: connect to 192.168.45.120[192.168.45.120]:25: Connection timed out',
'Oct 30 13:08:09 ebox011101 postfix/smtp[16770]: 6E06752608: to=<jag@gmail.com>, relay=none, delay=30, delays=0.06/0.02/30/0, dsn=4.4.1, status=deferred (connect to 192.168.45.120[192.168.45.120]:25: Connection timed out)',

                          ],
              expectedData =>  {
                               from_address => 'spam@warp.es',
                               message_id => '200811181346.45800.spam@warp.es',
                               message_size => '580',
                               status => 'deferred',
                               postfix_date => '2008-Oct-30 13:08:09',
                               event => 'nohost',
                               message => 'connect to 192.168.45.120[192.168.45.120]:25: Connection timed out',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => 'none, delay=30, delays=0.06/0.02/30/0',
                               client_host_ip => '192.168.9.1'
                              },

             },


             {
              name => 'Error. Smarthost and client have the same hostname',
                 lines => [

'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: 7B98D5262E: client=unknown[192.168.9.1]',
'Oct 30 13:13:09 ebox011101 postfix/cleanup[17166]: 7B98D5262E: message-id=<200811181352.16952.spam@warp.es>',
'Oct 30 13:13:09 ebox011101 postfix/qmgr[16604]: 7B98D5262E: from=<spam@warp.es>, size=580, nrcpt=1 (queue active)',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: disconnect from unknown[192.168.9.1]',
'Oct 30 13:13:10 ebox011101 postfix/smtp[17167]: warning: host 192.168.45.120[192.168.45.120]:25 replied to HELO/EHLO with my own hostname ebox011101.lan.hq.warp.es',
'Oct 30 13:13:10 ebox011101 postfix/smtp[17167]: 7B98D5262E: to=<jag@gmail.com>, relay=192.168.45.120[192.168.45.120]:25, delay=0.56, delays=0.04/0.02/0.5/0, dsn=5.4.6, status=bounced (mail for 192.168.45.120 loops back to myself)',
'Oct 30 13:13:10 ebox011101 postfix/bounce[17168]: 7B98D5262E: sender non-delivery notification: 10ADB52631',
'Oct 30 13:13:10 ebox011101 postfix/qmgr[16604]: 7B98D5262E: removed',


                          ],
              expectedData =>  {
                               from_address => 'spam@warp.es',
                               message_id => '200811181352.16952.spam@warp.es',
                               message_size => '580',
                               status => 'bounced',
                               postfix_date => '2008-Oct-30 13:13:10',
                               event => 'other',
                               message => 'mail for 192.168.45.120 loops back to myself',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => '192.168.45.120[192.168.45.120]:25, delay=0.56, delays=0.04/0.02/0.5/0',
                               client_host_ip => '192.168.9.1'
                              },

             },


            );
 


my $logHelper = new EBox::MailLogHelper();

foreach my $case (@cases) {
    diag $case->{name};

    my @lines = @{ $case->{lines} };

    my $dbEngine = newFakeDBEngine();
    lives_ok {
        foreach my $line (@lines) {
            $logHelper->processLine('fakeFile', $line, $dbEngine); 
        }
    } 'processing lines';

    checkInsert($dbEngine, $case->{expectedData});
}



1;

__END__




                 





tratando enviar con auth cuando no esre querida:

Aug 25 09:21:34 intrepid postfix/smtpd[4270]: connect from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: setting up TLS connection from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: Anonymous TLS connection established from unknown[192.168.45.159]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: lost connection after AUTH from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: disconnect from unknown[192.168.45.159]


tratando usar TSL cuando n oesta activo

Aug 25 09:35:53 intrepid postfix/smtpd[4161]: connect from unknown[192.168.45.159]
Aug 25 09:35:53 intrepid postfix/smtpd[4161]: lost connection after STARTTLS from unknown[192.168.45.159]
Aug 25 09:35:53 intrepid postfix/smtpd[4161]: disconnect from unknown[192.168.45.159]
