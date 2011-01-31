# Copyright (C) 2008-2011 eBox Technologies S.L.
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

use Test::More tests => 95;
use Test::MockObject;
use Test::Exception;

use EBox::TestStubs;

use Data::Dumper;

my $dumpInsertedData = 0;

use constant TABLENAME => "mail_message";


{
    no warnings 'redefine';
    sub EBox::Global::modInstance
     {
         my ($class, $name) = @_;
    
         if ($name ne 'mail') {
             die 'Only mocked EBox::Global::modInstance for module mail';
         }
    

         my $fakeVDomains = Test::MockObject->new();
         $fakeVDomains->mock('vdomains' => sub {
                                 return ('monos.org', 'a.com')
                             }
                            );

         my $mailMod = {
                        vdomains => $fakeVDomains,
                       };

         return $mailMod;
     }
}





sub newFakeDBEngine
{
    my $dbengine = Test::MockObject->new();
    $dbengine->{nInserts} = 0;

    $dbengine->mock('insert' => sub {
                        my ($self, $table, $data) = @_;
                        $self->{insertedTable} = $table;
                        $self->{insertedData}  = $data;
                        $self->{nInserts} += 1;
                    }
                   );
    return $dbengine;
}
                    

sub _currentYear
{
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
    $year += 1900;
    return $year;
}


sub checkInsert
{
    my ($dbengine, $expectedData) = @_;

    my $table = delete $dbengine->{insertedTable};
    is $table, TABLENAME,
        'checking that the insert was made in the mail log table';
    my $nInserts = delete $dbengine->{nInserts};
    is 1, $nInserts,
        'checking that insert was done only one time per case';
    
    my $data = delete $dbengine->{insertedData};
    if ($dumpInsertedData) {
        diag "Inserted Data:\n" . Dumper $data;
    }

    my @notNullFields = qw(client_host_ip client_host_name timestamp);
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

my $year = _currentYear();
my @cases = (
             {
              name => 'Message sent to external account with both TSL and SASL active',
              lines => [
'Oct  1 11:47:51 u86 postfix/smtpd[10242]: connect from unknown[192.168.9.1]',
'Oct  1 11:47:51 u86 postfix/smtpd[10242]: setting up TLS connection from unknown[192.168.9.1]',
'Oct  1 11:47:51 u86 postfix/smtpd[10242]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct  1 11:47:51 u86 postfix/smtpd[10242]: DBED828417: client=unknown[192.168.9.1], sasl_method=PLAIN, sasl_username=macaco@monos.org',
'Oct  1 11:47:51 u86 postfix/cleanup[10247]: DBED828417: message-id=<465387.531879486-sendEmail@huginn>',
'Oct  1 11:47:51 u86 postfix/qmgr[9572]: DBED828417: from=<macaco@monos.org>, size=890, nrcpt=2 (queue active)',
'Oct  1 11:47:52 u86 postfix/smtpd[10242]: disconnect from unknown[192.168.9.1]',
'Oct  1 11:47:53 u86 postfix/smtp[10248]: DBED828417: to=<jamor@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.6, delays=0.17/0.04/0.88/0.48, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as C1EBF731439)',
'Oct  1 11:47:53 u86 postfix/smtp[10248]: DBED828417: to=<jamor@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.6, delays=0.17/0.04/0.88/0.48, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as C1EBF731439)',
'Oct  1 11:47:53 u86 postfix/qmgr[9572]: DBED828417: removed',

                       ],
              expectedData =>  {
                               from_address => 'macaco@monos.org',
                               message_id => '465387.531879486-sendEmail@huginn',
                               message_size => 890,
                               status => 'sent',
                               timestamp => "$year-Oct-1 11:47:53",
                               event => 'msgsent',
                               message => '250 2.0.0 Ok: queued as C1EBF731439',
                               to_address => 'jamor@dplanet.com',
                               client_host_name => 'unknown',
                               relay => 'mail.dplanet.com[67.23.8.134]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'sent',
                              },
             },

             {
              name => 'Message sent to external account with network object authorization',
              lines => [
'Oct  1 12:22:56 u86 postfix/smtpd[12395]: connect from unknown[192.168.9.1]',
'Oct  1 12:22:56 u86 postfix/smtpd[12395]: 81CBA28781: client=unknown[192.168.9.1]',
'Oct  1 12:22:56 u86 postfix/cleanup[12398]: 81CBA28781: message-id=<169058.974457101-sendEmail@huginn>',
'Oct  1 12:22:56 u86 postfix/qmgr[11088]: 81CBA28781: from=<macaco@monos.org>, size=888, nrcpt=2 (queue active)',
'Oct  1 12:22:56 u86 postfix/smtpd[12395]: disconnect from unknown[192.168.9.1]',
'Oct  1 12:22:57 u86 postfix/smtp[12399]: 81CBA28781: to=<jamor@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.3, delays=0.16/0.02/0.62/0.48, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 538DA731439)',
'Oct  1 12:22:57 u86 postfix/smtp[12399]: 81CBA28781: to=<jamor@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.3, delays=0.16/0.02/0.62/0.48, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 538DA731439)',
'Oct  1 12:22:57 u86 postfix/qmgr[11088]: 81CBA28781: removed',
                       ],
              expectedData =>  {
                               from_address => 'macaco@monos.org',
                               message_id => '169058.974457101-sendEmail@huginn',
                               message_size => 888,
                               status => 'sent',
                               timestamp => "$year-Oct-1 12:22:57",
                               event => 'msgsent',
                               message => '250 2.0.0 Ok: queued as 538DA731439',
                               to_address => 'jamor@dplanet.com',
                               client_host_name => 'unknown',
                               relay => 'mail.dplanet.com[67.23.8.134]:25',
                               client_host_ip => '192.168.9.1',
                                message_type => 'sent',
                              },
             },

             {
              name => 'Message sent with TSL but no  SASL to a local mail domain account',
              lines => [
'Oct  1 06:58:29 u86 postfix/smtpd[25248]: connect from unknown[192.168.9.1]',
'Oct  1 06:58:29 u86 postfix/smtpd[25248]: setting up TLS connection from unknown[192.168.9.1]',
'Oct  1 06:58:29 u86 postfix/smtpd[25248]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct  1 06:58:29 u86 postfix/smtpd[25248]: AFDB128599: client=unknown[192.168.9.1]',
'Oct  1 06:58:29 u86 postfix/cleanup[25253]: AFDB128599: message-id=<773316.468668298-sendEmail@huginn>',
'Oct  1 06:58:29 u86 postfix/qmgr[25083]: AFDB128599: from=<jamor@example.com>, size=874, nrcpt=1 (queue active)',
'Oct  1 06:58:29 u86 postfix/smtpd[25248]: disconnect from unknown[192.168.9.1]',
'Oct  1 06:58:29 u86 deliver(macaco@monos.org): msgid=<773316.468668298-sendEmail@huginn>: saved mail to INBOX',
'Oct  1 06:58:29 u86 postfix/pipe[25254]: AFDB128599: to=<macaco@monos.org>, relay=dovecot, delay=0.25, delays=0.15/0.03/0/0.06, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Oct  1 06:58:29 u86 postfix/qmgr[25083]: AFDB128599: removed',
                       ],
              expectedData =>  {
                               from_address => 'jamor@example.com',
                               message_id => '773316.468668298-sendEmail@huginn',
                               message_size => 874,
                               status => 'sent',
                               timestamp => "$year-Oct-1 06:58:29",
                               event => 'msgsent',
                               message => 'delivered via dovecot service',
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'dovecot',
                               client_host_ip => '192.168.9.1',
                                message_type => 'received',
                              },

             },
             {
              # XXX no longer valid bz change to ldap transport
              name => 'Message sent to vdomain account without TSL or SASL',
                 lines => [
'Oct  1 06:41:17 u86 postfix/smtpd[13237]: connect from unknown[192.168.9.1]',
'Oct  1 06:41:17 u86 postfix/smtpd[13237]: D198328360: client=unknown[192.168.9.1]',
'Oct  1 06:41:17 u86 postfix/cleanup[13241]: D198328360: message-id=<960540.392293723-sendEmail@huginn>',
'Oct  1 06:41:17 u86 postfix/qmgr[12460]: D198328360: from=<jamor@example.com>, size=873, nrcpt=1 (queue active)',
'Oct  1 06:41:17 u86 postfix/smtpd[13237]: disconnect from unknown[192.168.9.1]',
'Oct  1 06:41:18 u86 deliver(macaco@monos.org): msgid=<960540.392293723-sendEmail@huginn>: saved mail to INBOX',
'Oct  1 06:41:18 u86 postfix/pipe[13242]: D198328360: to=<macaco@monos.org>, relay=dovecot, delay=0.24, delays=0.11/0.04/0/0.09, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Oct  1 06:41:18 u86 postfix/qmgr[12460]: D198328360: removed',
                          ],
              expectedData =>  {
                               from_address => 'jamor@example.com',
                               message_id => '960540.392293723-sendEmail@huginn',
                               message_size => '873',
                               status => 'sent',
                               timestamp => "$year-Oct-1 06:41:18",
                               event => 'msgsent',
                               message => 'delivered via dovecot service',
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'dovecot',
                               client_host_ip => '192.168.9.1',
                               message_type => 'received',
                              },

             },
             
             {
              name => 'Bounced message; sent to a inexitent account in a external server',
              lines => [
'Oct  1 12:18:15 u86 postfix/smtpd[12101]: connect from unknown[192.168.9.1]',
'Oct  1 12:18:15 u86 postfix/smtpd[12101]: 72FEB28781: client=unknown[192.168.9.1]',
'Oct  1 12:18:15 u86 postfix/cleanup[12104]: 72FEB28781: message-id=<474771.820564882-sendEmail@huginn>',
'Oct  1 12:18:15 u86 postfix/qmgr[11088]: 72FEB28781: from=<macaco@monos.org>, size=885, nrcpt=2 (queue active)',
'Oct  1 12:18:15 u86 postfix/smtpd[12101]: disconnect from unknown[192.168.9.1]',
'Oct  1 12:18:16 u86 postfix/smtp[12105]: 72FEB28781: to=<nobj@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.3, delays=0.29/0.03/0.63/0.36, dsn=5.1.1, status=bounced (host mail.dplanet.com[67.23.8.134] said: 550 5.1.1 <nobj@dplanet.com>: Recipient address rejected: User unknown in virtual mailbox table (in reply to RCPT TO command))',
'Oct  1 12:18:16 u86 postfix/smtp[12105]: 72FEB28781: to=<jamor@dplanet.com>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.5, delays=0.29/0.03/0.63/0.56, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 43EC9731439)',
'Oct  1 12:18:16 u86 postfix/cleanup[12104]: B876628785: message-id=<20091001161816.B876628785@u86>',
'Oct  1 12:18:16 u86 postfix/qmgr[11088]: B876628785: from=<>, size=2808, nrcpt=1 (queue active)',
'Oct  1 12:18:16 u86 postfix/bounce[12107]: 72FEB28781: sender non-delivery notification: B876628785',
'Oct  1 12:18:16 u86 postfix/qmgr[11088]: 72FEB28781: removed',
'Oct  1 12:18:16 u86 deliver(macaco@monos.org): msgid=<20091001161816.B876628785@u86>: saved mail to INBOX',
'Oct  1 12:18:16 u86 postfix/pipe[12108]: B876628785: to=<macaco@monos.org>, relay=dovecot, delay=0.12, delays=0.04/0.03/0/0.05, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Oct  1 12:18:16 u86 postfix/qmgr[11088]: B876628785: removed',
                       ],
              expectedData =>  {
                               from_address => 'macaco@monos.org',
                               message_id => '474771.820564882-sendEmail@huginn',
                               message_size => 885,
                               status => 'bounced',
                               timestamp => "$year-Oct-1 12:18:16",
                               event => 'other',
                               message => 'host mail.dplanet.com[67.23.8.134] said: 550 5.1.1 <nobj@dplanet.com>: Recipient address rejected: User unknown in virtual mailbox table (in reply to RCPT TO command)',
                               to_address => 'nobj@dplanet.com',
                               client_host_name => 'unknown',
                               relay => 'mail.dplanet.com[67.23.8.134]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'sent',
                              },
             },

             {
              name => 'Message relayed trough external smarthost',
                 lines => [
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: connect from unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: 2AF6952626: client=unknown[192.168.9.1]',
'Oct 30 11:00:07 ebox011101 postfix/cleanup[32275]: 2AF6952626: message-id=<200811181139.13287.spam@zentyal.org>',
'Oct 30 11:00:07 ebox011101 postfix/qmgr[31065]: 2AF6952626: from=<spam@zentyal.org>, size=580, nrcpt=1 (queue active)',
'Oct 30 11:00:07 ebox011101 postfix/smtpd[32271]: disconnect from unknown[192.168.9.1]',
'Oct 30 11:00:22 ebox011101 postfix/smtp[32362]: 2AF6952626: to=<jag@gmail.com>, relay=smtp.zentyal.org[82.194.70.220]:25, delay=15, delays=0.03/0/6.9/8.3, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 3F7CEBC608)',
'Oct 30 11:00:22 ebox011101 postfix/qmgr[31065]: 2AF6952626: removed',

                          ],
              expectedData =>  {
                               from_address => 'spam@zentyal.org',
                               message_id => '200811181139.13287.spam@zentyal.org',
                               message_size => '580',
                               status => 'sent',
                               timestamp => "$year-Oct-30 11:00:22",
                               event => 'msgsent',
                               message => '250 2.0.0 Ok: queued as 3F7CEBC608',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => 'smtp.zentyal.org[82.194.70.220]:25',
                               client_host_ip => '192.168.9.1',
                                message_type => 'relay',
                              },

             },

             {
              name => 'Message relayed to unavailable external smarthost',
                 lines => [
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: connect from unknown[192.168.9.1]',
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 13:07:38 ebox011101 postfix/smtpd[16765]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 13:07:39 ebox011101 postfix/smtpd[16765]: 6E06752608: client=unknown[192.168.9.1]',
'Oct 30 13:07:39 ebox011101 postfix/cleanup[16769]: 6E06752608: message-id=<200811181346.45800.spam@zentyal.org>',
'Oct 30 13:07:39 ebox011101 postfix/qmgr[16604]: 6E06752608: from=<spam@zentyal.org>, size=580, nrcpt=1 (queue active)',
'Oct 30 13:07:39 ebox011101 postfix/smtpd[16765]: disconnect from unknown[192.168.9.1]',
'Oct 30 13:08:09 ebox011101 postfix/smtp[16770]: connect to 192.168.45.120[192.168.45.120]:25: Connection timed out',
'Oct 30 13:08:09 ebox011101 postfix/smtp[16770]: 6E06752608: to=<jag@gmail.com>, relay=none, delay=30, delays=0.06/0.02/30/0, dsn=4.4.1, status=deferred (connect to 192.168.45.120[192.168.45.120]:25: Connection timed out)',

                          ],
              expectedData =>  {
                               from_address => 'spam@zentyal.org',
                               message_id => '200811181346.45800.spam@zentyal.org',
                               message_size => '580',
                               status => 'deferred',
                               timestamp => "$year-Oct-30 13:08:09",
                               event => 'nohost',
                               message => 'connect to 192.168.45.120[192.168.45.120]:25: Connection timed out',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => 'none',
                               client_host_ip => '192.168.9.1',
                               message_type => 'relay',
                              },

             },


             {
              name => 'Error. Smarthost and client have the same hostname',
                 lines => [

'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: 7B98D5262E: client=unknown[192.168.9.1]',
'Oct 30 13:13:09 ebox011101 postfix/cleanup[17166]: 7B98D5262E: message-id=<200811181352.16952.spam@zentyal.org>',
'Oct 30 13:13:09 ebox011101 postfix/qmgr[16604]: 7B98D5262E: from=<spam@zentyal.org>, size=580, nrcpt=1 (queue active)',
'Oct 30 13:13:09 ebox011101 postfix/smtpd[17163]: disconnect from unknown[192.168.9.1]',
'Oct 30 13:13:10 ebox011101 postfix/smtp[17167]: warning: host 192.168.45.120[192.168.45.120]:25 replied to HELO/EHLO with my own hostname ebox011101.lan.hq.zentyal.org',
'Oct 30 13:13:10 ebox011101 postfix/smtp[17167]: 7B98D5262E: to=<jag@gmail.com>, relay=192.168.45.120[192.168.45.120]:25, delay=0.56, delays=0.04/0.02/0.5/0, dsn=5.4.6, status=bounced (mail for 192.168.45.120 loops back to myself)',
'Oct 30 13:13:10 ebox011101 postfix/bounce[17168]: 7B98D5262E: sender non-delivery notification: 10ADB52631',
'Oct 30 13:13:10 ebox011101 postfix/qmgr[16604]: 7B98D5262E: removed',


                          ],
              expectedData =>  {
                               from_address => 'spam@zentyal.org',
                               message_id => '200811181352.16952.spam@zentyal.org',
                               message_size => '580',
                               status => 'bounced',
                               timestamp => "$year-Oct-30 13:13:10",
                               event => 'other',
                               message => 'mail for 192.168.45.120 loops back to myself',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => '192.168.45.120[192.168.45.120]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'relay',
                              },

             },

             {
              name => 'Remote smarthost denies relay',
                 lines => [
'Oct 30 16:22:18 ebox011101 postfix/smtpd[22313]: connect from unknown[192.168.9.1]',
'Oct 30 16:22:18 ebox011101 postfix/smtpd[22313]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 30 16:22:18 ebox011101 postfix/smtpd[22313]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 30 16:22:19 ebox011101 postfix/smtpd[22313]: 0649F5262D: client=unknown[192.168.9.1]',
'Oct 30 16:22:19 ebox011101 postfix/cleanup[22316]: 0649F5262D: message-id=<200811181701.17282.spam@zentyal.org>',
'Oct 30 16:22:19 ebox011101 postfix/qmgr[16604]: 0649F5262D: from=<spam@zentyal.org>, size=580, nrcpt=1 (queue active)',
'Oct 30 16:22:19 ebox011101 postfix/smtpd[22313]: disconnect from unknown[192.168.9.1]',
'Oct 30 16:22:19 ebox011101 postfix/smtp[22317]: 0649F5262D: to=<jag@gmail.com>, relay=192.168.45.120[192.168.45.120]:25, delay=0.36, delays=0.16/0.02/0.09/0.09, dsn=5.7.1, status=bounced (host 192.168.45.120[192.168.45.120] said: 554 5.7.1 <jag@gmail.com>: Relay access denied (in reply to RCPT TO command))',
'Oct 30 16:22:19 ebox011101 postfix/bounce[22318]: 0649F5262D: sender non-delivery notification: 5A4B352630',
'Oct 30 16:22:19 ebox011101 postfix/qmgr[16604]: 0649F5262D: removed',
                          ],
              expectedData =>  {
                               from_address => 'spam@zentyal.org',
                               message_id => '200811181701.17282.spam@zentyal.org',
                               message_size => '580',
                               status => 'bounced',
                               timestamp => "$year-Oct-30 16:22:19",
                               event => 'nosmarthostrelay',
                               message => 'host 192.168.45.120[192.168.45.120] said: 554 5.7.1 <jag@gmail.com>: Relay access denied (in reply to RCPT TO command)',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => '192.168.45.120[192.168.45.120]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'relay',
                              },

             },

             {
              name => 'Remote smarthost authentication error',
                 lines => [
'Oct 31 00:21:29 ebox011101 postfix/smtpd[11062]: connect from unknown[192.168.9.1]',
'Oct 31 00:21:29 ebox011101 postfix/smtpd[11062]: setting up TLS connection from unknown[192.168.9.1]',
'Oct 31 00:21:29 ebox011101 postfix/smtpd[11062]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct 31 00:21:29 ebox011101 postfix/smtpd[11062]: 0158C52634: client=unknown[192.168.9.1]',
'Oct 31 00:21:30 ebox011101 postfix/cleanup[11065]: 0158C52634: message-id=<200811191624.44633.spam@zentyal.org>',
'Oct 31 00:21:30 ebox011101 postfix/qmgr[10852]: 0158C52634: from=<spam@zentyal.org>, size=580, nrcpt=1 (queue active)',
'Oct 31 00:21:30 ebox011101 postfix/error[11066]: 0158C52634: to=<jag@gmail.com>, relay=none, delay=0.1, delays=0.06/0.02/0/0.02, dsn=4.7.8, status=deferred (delivery temporarily suspended: SASL authentication failed; server 192.168.45.120[192.168.45.120] said: 535 5.7.8 Error: authentication failed: authentication failure)',
'Oct 31 00:21:30 ebox011101 postfix/smtpd[11062]: disconnect from unknown[192.168.9.1]',

                          ],
              expectedData =>  {
                               from_address => 'spam@zentyal.org',
                               message_id => '200811191624.44633.spam@zentyal.org',
                               message_size => '580',
                               status => 'deferred',
                               timestamp => "$year-Oct-31 00:21:30",
                               event => 'nosmarthostrelay',
                               message => 'delivery temporarily suspended: SASL authentication failed; server 192.168.45.120[192.168.45.120] said: 535 5.7.8 Error: authentication failed: authentication failure',
                               to_address => 'jag@gmail.com',
                               client_host_name => 'unknown',
                               relay => 'none',
                               client_host_ip => '192.168.9.1',
                               message_type => 'relay',
                              },

             },

             {
              name => 'Sending mail to a greylisted external server',
                 lines => [

'Jul 13 09:42:04 ebox011101 postfix/smtpd[2986]: connect from unknown[192.168.9.1]',
'Jul 13 09:42:04 ebox011101 postfix/smtpd[2986]: setting up TLS connection from unknown[192.168.9.1]',
'Jul 13 09:42:04 ebox011101 postfix/smtpd[2986]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Jul 13 09:42:04 ebox011101 postfix/smtpd[2986]: 20A6F5265A: client=unknown[192.168.9.1]',
'Jul 13 09:42:04 ebox011101 postfix/cleanup[2989]: 20A6F5265A: message-id=<604958.427461924-sendEmail@localhost>',
'Jul 13 09:42:04 ebox011101 postfix/qmgr[2256]: 20A6F5265A: from=<a@a.com>, size=909, nrcpt=1 (queue active)',
'Jul 13 09:42:04 ebox011101 postfix/smtpd[2986]: disconnect from unknown[192.168.9.1]',
'Jul 13 09:42:05 ebox011101 postfix/smtp[2990]: 20A6F5265A: to=<ckent@dplanet.com>, relay=smtp.dplanet.com[67.23.2.154]:25, delay=1.6, delays=0.61/0/0.6/0.37, dsn=4.2.0, status=deferred (host smtp.dplanet.com[67.23.2.154] said: 450 4.2.0 <ckent@dplanet.com>: Recipient address rejected: Greylisted, see http://postgrey.schweikert.ch/help/dplanet.com.html (in reply to RCPT TO command))',
                          ],
              expectedData =>  {
                               from_address => 'a@a.com',
                               message_id => '604958.427461924-sendEmail@localhost',
                               message_size => '909',
                               status => 'deferred',
                               timestamp => "$year-Jul-13 09:42:05",
                               event => 'greylist',
                               message => 'host smtp.dplanet.com[67.23.2.154] said: 450 4.2.0 <ckent@dplanet.com>: Recipient address rejected: Greylisted, see http://postgrey.schweikert.ch/help/dplanet.com.html (in reply to RCPT TO command)',
                               to_address => 'ckent@dplanet.com',
                               client_host_name => 'unknown',
                               relay => 'smtp.dplanet.com[67.23.2.154]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'sent',
                              },

             },

             {
                name => 'Relay access denied',
                 lines => [
'Sep 23 10:21:17 ebox011101 postfix/smtpd[14747]: connect from unknown[192.168.9.1]',
'Sep 23 10:21:21 ebox011101 postfix/smtpd[14747]: NOQUEUE: reject: RCPT from unknown[192.168.9.1]: 554 5.7.1 <ckent@dplanet.com>: Relay access denied; from=<macaco@monos.org> to=<ckent@dplanet.com> proto=ESMTP helo=<localhost.localdomain>',
'Sep 23 10:21:21 ebox011101 postfix/smtpd[14747]: lost connection after RCPT from unknown[192.168.9.1]',
'Sep 23 10:21:21 ebox011101 postfix/smtpd[14747]: disconnect from unknown[192.168.9.1]',
                          ],
              expectedData =>  {
                               from_address => 'macaco@monos.org',
                               status => 'reject',
                               timestamp => "$year-Sep-23 10:21:21",
                               event => 'norelay',
                               message => '554 5.7.1 <ckent@dplanet.com>: Relay access denied',
                               to_address => 'ckent@dplanet.com',
                               client_host_name => 'unknown',
                               client_host_ip => '192.168.9.1',
                               message_type => 'sent',
                              },

             },

             {
                 name => 'SASL authentication error',
                 lines => [
'Oct  1 07:04:35 u86 postfix/smtpd[25859]: connect from unknown[192.168.9.1]',
'Oct  1 07:04:35 u86 postfix/smtpd[25859]: setting up TLS connection from unknown[192.168.9.1]',
'Oct  1 07:04:35 u86 postfix/smtpd[25859]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct  1 07:04:37 u86 postfix/smtpd[25859]: warning: unknown[192.168.9.1]: SASL PLAIN authentication failed:',
'Oct  1 07:04:37 u86 postfix/smtpd[25859]: lost connection after AUTH from unknown[192.168.9.1]',
'Oct  1 07:04:37 u86 postfix/smtpd[25859]: disconnect from unknown[192.168.9.1]',
                ],
              expectedData =>  {
                               timestamp => "$year-Oct-1 07:04:37",
                               event => 'noauth',
                               client_host_name => 'unknown',
                               client_host_ip => '192.168.9.1',
                               message_type => 'unknown',
                              },                 
                 
                },

             {
                 name => 'helo reject. (NOQUEUE event)',
                 lines => [
'Oct  1 12:45:08 u86 postfix/smtpd[14328]: connect from unknown[192.168.9.1]',
'Oct  1 12:45:08 u86 postfix/smtpd[14328]: NOQUEUE: reject: RCPT from unknown[192.168.9.1]: 504 5.5.2 <huginn>: Helo command rejected: need fully-qualified hostname; from=<sender2@gmail.com> to=<macaco@monos.org> proto=ESMTP helo=<huginn>',
'Oct  1 12:45:08 u86 postfix/smtpd[14328]: lost connection after RCPT from unknown[192.168.9.1]',
'Oct  1 12:45:08 u86 postfix/smtpd[14328]: disconnect from unknown[192.168.9.1]',
                    ],
              expectedData =>  {
                               timestamp => "$year-Oct-1 12:45:08",
                               event => 'other',
                               client_host_name => 'unknown',
                               client_host_ip => '192.168.9.1',
                               from_address => 'sender2@gmail.com',
                               to_address => 'macaco@monos.org',
                               status => 'reject',
                               message =>'504 5.5.2 <huginn>: Helo command rejected: need fully-qualified hostname',
                               message_type => 'received',
                              },                 

             },
#XXX this case seems to work in the real applcationm, strange..
#             {
#                 name => 'Deferred by external SMTP',
#                  lines => [
# 'Sep 23 10:57:38 ebox011101 postfix/smtpd[15939]: connect from unknown[192.168.9.1]',
# 'Sep 23 10:57:40 ebox011101 postfix/smtpd[15939]: setting up TLS connection from unknown[192.168.9.1]',
# 'Sep 23 10:57:41 ebox011101 postfix/smtpd[15939]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
# 'Sep 23 10:57:45 ebox011101 postfix/smtpd[15939]: 48D98526BC: client=unknown[192.168.9.1], sasl_method=PLAIN, sasl_username=macaco@monos.org',
# 'Sep 23 10:57:45 ebox011101 postfix/cleanup[15977]: 48D98526BC: message-id=<383994.577310176-sendEmail@localhost>',
# 'Sep 23 10:57:45 ebox011101 postfix/qmgr[15873]: 48D98526BC: from=<macaco@monos.org>, size=935, nrcpt=1 (queue active)',
# 'Sep 23 10:57:45 ebox011101 postfix/smtpd[15939]: disconnect from unknown[192.168.9.1]',
# 'Sep 23 10:58:19 ebox011101 postfix/smtp[15981]: 48D98526BC: host gmail-smtp-in.l.google.com[209.85.219.2] said: 421-4.7.0 [88.16.31.62] Our system has detected an unusual amount of unsolicited 421-4.7.0 mail originating from your IP address. To protect our users from 421-4.7.0 spam, mail sent from your IP address has been temporarily blocked. 421-4.7.0 Please visit http://www.google.com/mail/help/bulk_mail.html to review 421 4.7.0 our Bulk Email Senders Guidelines. 2si6795794ewy.104 (in reply to end of DATA command)',


#                           ],
#               expectedData =>  {
#                                from_address => 'macaco@monos.org',
#                                status => 'deferred',
#                                timestamp => "$year-Sep-23 10:21:21",
#                                event => 'norelay',
#                                message => '554 5.7.1 <ckent@dplanet.com>: Relay access denied',
#                                to_address => 'ckent@dplanet.com',
#                                client_host_name => 'unknown',
#                                client_host_ip => '192.168.9.1'
#                               },

#              },

             {
                 name => 'User quota exceeded',
                 lines => [
'Oct  1 07:49:19 u86 postfix/smtpd[27306]: connect from unknown[192.168.9.1]',
'Oct  1 07:49:19 u86 postfix/smtpd[27306]: setting up TLS connection from unknown[192.168.9.1]',
'Oct  1 07:49:19 u86 postfix/smtpd[27306]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct  1 07:49:19 u86 postfix/smtpd[27306]: 850AE2845F: client=unknown[192.168.9.1]',
'Oct  1 07:49:19 u86 postfix/cleanup[27310]: 850AE2845F: message-id=<319615.810035856-sendEmail@huginn>',
'Oct  1 07:49:20 u86 postfix/qmgr[26878]: 850AE2845F: from=<jamor@example.com>, size=4065462, nrcpt=1 (queue active)',
'Oct  1 07:49:20 u86 deliver(macaco@monos.org): msgid=<319615.810035856-sendEmail@huginn>: save failed to INBOX: Quota exceeded (mailbox for user is full)',
'Oct  1 07:49:20 u86 deliver(macaco@monos.org): msgid=<319615.810035856-sendEmail@huginn>: rejected: Quota exceeded (mailbox for user is full)',
'Oct  1 07:49:20 u86 postfix/smtpd[27306]: disconnect from unknown[192.168.9.1]',
'Oct  1 07:49:20 u86 postfix/pickup[26876]: DA6C8285A6: uid=109 from=<>',
'Oct  1 07:49:20 u86 postfix/cleanup[27310]: DA6C8285A6: message-id=<dovecot-1254397760-467815-0@u86>',
'Oct  1 07:49:20 u86 postfix/pipe[27311]: 850AE2845F: to=<macaco@monos.org>, relay=dovecot, delay=1.4, delays=0.92/0.03/0/0.47, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Oct  1 07:49:20 u86 postfix/qmgr[26878]: 850AE2845F: removed',

                    ],
              expectedData =>  {
                               from_address => 'jamor@example.com',
                               message_id => '319615.810035856-sendEmail@huginn',
                               message_size => 4065462,
                               status => 'rejected',
                               timestamp => "$year-Oct-1 07:49:20",
                               event => 'maxusrsize',
                               message => undef,
                               to_address => 'macaco@monos.org',
                               client_host_name => 'unknown',
                               relay => 'dovecot',
                               client_host_ip => '192.168.9.1',
                               message_type => 'received',
                              },

                },


             {
                 name => 'Message size exceeded',
                 lines => [
'Oct  1 07:46:26 u86 postfix/smtpd[2847]: connect from unknown[192.168.9.1]',
'Oct  1 07:46:26 u86 postfix/smtpd[2847]: setting up TLS connection from unknown[192.168.9.1]',
'Oct  1 07:46:26 u86 postfix/smtpd[2847]: Anonymous TLS connection established from unknown[192.168.9.1]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)',
'Oct  1 07:46:26 u86 postfix/smtpd[2847]: C48C428351: client=unknown[192.168.9.1], sasl_method=PLAIN, sasl_username=macaco@monos.org',
'Oct  1 07:46:26 u86 postfix/cleanup[2882]: C48C428351: message-id=<942511.878066824-sendEmail@huginn>',
'Oct  1 07:46:27 u86 postfix/smtpd[2847]: warning: C48C428351: queue file size limit exceeded',
'Oct  1 07:46:27 u86 postfix/smtpd[2847]: disconnect from unknown[192.168.9.1]',
],
              expectedData =>  {
                               from_address => undef,
                               message_id => '942511.878066824-sendEmail@huginn',
                               message_size => undef,
                               status => 'rejected',
                               timestamp => "$year-Oct-1 07:46:27",
                               event => 'maxmsgsize',
                               message => undef,
                               to_address => undef,
                               client_host_name => 'unknown',
                               relay => undef,
                               client_host_ip => '192.168.9.1',
                               message_type => 'unknown',
                              },
                },

             {
                 name => 'Mail to group alias',
                 lines => [
'Dec 28 03:57:57 ebox011101 postfix/smtpd[25837]: connect from unknown[192.168.9.1]',
'Dec 28 03:57:57 ebox011101 postfix/smtpd[25837]: B3F76526DC: client=unknown[192.168.9.1]',
'Dec 28 03:57:57 ebox011101 postfix/cleanup[25840]: B3F76526DC: message-id=<809240.389472933-sendEmail@localhost>',
'Dec 28 03:57:57 ebox011101 postfix/qmgr[25697]: B3F76526DC: from=<jamor@dplanet.com>, size=902, nrcpt=2 (queue active)',
'Dec 28 03:57:57 ebox011101 postfix/smtpd[25837]: disconnect from unknown[192.168.9.1]',
'Dec 28 03:58:00 ebox011101 deliver(macaco@monos.org): msgid=<809240.389472933-sendEmail@localhost>: saved mail to INBOX',
'Dec 28 03:58:00 ebox011101 postfix/pipe[25841]: B3F76526DC: to=<macaco@monos.org>, orig_to=<all@monos.org>, relay=dovecot, delay=2.6, delays=0.23/0.02/0/2.4, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Dec 28 03:58:00 ebox011101 deliver(mandrill@monos.org): msgid=<809240.389472933-sendEmail@localhost>: saved mail to INBOX',
'Dec 28 03:58:00 ebox011101 postfix/pipe[25842]: B3F76526DC: to=<mandrill@monos.org>, orig_to=<all@monos.org>, relay=dovecot, delay=2.6, delays=0.23/0.03/0/2.4, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Dec 28 03:58:00 ebox011101 postfix/qmgr[25697]: B3F76526DC: removed',
                          ],
              expectedData =>  {
                               from_address => 'jamor@dplanet.com',
                               message_id => '809240.389472933-sendEmail@localhost',
                               message_size => 902,
                               status => 'sent',
                               timestamp => "$year-Dec-28 03:58:00",
                               event => 'msgsent',
                               message => 'delivered via dovecot service',
                               to_address => 'all@monos.org',
                               client_host_name => 'unknown',
                               relay => 'dovecot',
                               client_host_ip => '192.168.9.1',
                               message_type => 'received',
                              },
                },


             {
                 name => 'Mail to external alias',
                 lines => [
'Dec 28 04:47:28 ebox011101 postfix/smtpd[29097]: connect from unknown[192.168.9.1]',
'Dec 28 04:47:28 ebox011101 postfix/smtpd[29097]: 40F6852443: client=unknown[192.168.9.1]',
'Dec 28 04:47:28 ebox011101 postfix/cleanup[29100]: 40F6852443: message-id=<610511.014095636-sendEmail@localhost>',
'Dec 28 04:47:28 ebox011101 postfix/qmgr[27355]: 40F6852443: from=<jamor@dplanet.com>, size=914, nrcpt=1 (queue active)',
'Dec 28 04:47:28 ebox011101 postfix/smtpd[29097]: disconnect from unknown[192.168.9.1]',
'Dec 28 04:47:29 ebox011101 postfix/smtp[29101]: 40F6852443: to=<jamor@dplanet.com>, orig_to=<externo@monos.org>, relay=mail.dplanet.com[67.23.8.134]:25, delay=1.1, delays=0.07/0.03/0.56/0.46, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as B8CEB731480)',
'Dec 28 04:47:29 ebox011101 postfix/qmgr[27355]: 40F6852443: removed',
                          ],
              expectedData =>  {
                               from_address => 'jamor@dplanet.com',
                               message_id => '610511.014095636-sendEmail@localhost',
                               message_size => 914,
                               status => 'sent',
                               timestamp => "$year-Dec-28 04:47:29",
                               event => 'msgsent',
                               message => '250 2.0.0 Ok: queued as B8CEB731480',
                               to_address => 'externo@monos.org',
                               client_host_name => 'unknown',
                               relay => 'mail.dplanet.com[67.23.8.134]:25',
                               client_host_ip => '192.168.9.1',
                               message_type => 'received',
                              },
                },


             {
                 name => 'Mail to regular alias',
                 lines => [
# there is fetchmail output mixed in, other prgorams output could occur in any
# case..
'Dec 28 04:50:40 ebox011101 fetchmail[18083]: awakened at Mon 28 Dec 2009 04:50:40 AM EST',
'Dec 28 04:50:40 ebox011101 fetchmail[18083]: Server certificate verification error: unable to get local issuer certificate',
'Dec 28 04:50:41 ebox011101 fetchmail[18083]: Server certificate verification error: certificate not trusted',
'Dec 28 04:50:41 ebox011101 postfix/smtpd[29234]: connect from unknown[192.168.9.1]',
'Dec 28 04:50:41 ebox011101 postfix/smtpd[29234]: 98D3C526D8: client=unknown[192.168.9.1]',
'Dec 28 04:50:41 ebox011101 fetchmail[18083]: Server certificate verification error: unable to get local issuer certificate',
'Dec 28 04:50:41 ebox011101 fetchmail[18083]: Server certificate verification error: certificate not trusted',
'Dec 28 04:50:41 ebox011101 postfix/cleanup[29224]: 98D3C526D8: message-id=<570359.711625741-sendEmail@localhost>',
'Dec 28 04:50:41 ebox011101 postfix/qmgr[27355]: 98D3C526D8: from=<jamor@dplanet.com>, size=914, nrcpt=1 (queue active)',
'Dec 28 04:50:41 ebox011101 postfix/smtpd[29234]: disconnect from unknown[192.168.9.1]',
'Dec 28 04:50:42 ebox011101 fetchmail[18083]: Authorization failure on idle@gmail.com@gmail-pop.l.google.com',
'Dec 28 04:50:42 ebox011101 fetchmail[18083]: Query status=3 (AUTHFAIL)',
'Dec 28 04:50:42 ebox011101 fetchmail[18083]: sleeping at Mon 28 Dec 2009 04:50:42 AM EST for 180 seconds',
'Dec 28 04:50:42 ebox011101 deliver(macaco@monos.org): msgid=<570359.711625741-sendEmail@localhost>: saved mail to INBOX',
'Dec 28 04:50:42 ebox011101 postfix/pipe[29237]: 98D3C526D8: to=<macaco@monos.org>, orig_to=<macaco2@monos.org>, relay=dovecot, delay=1.5, delays=0.42/0.01/0/1.1, dsn=2.0.0, status=sent (delivered via dovecot service)',
'Dec 28 04:50:42 ebox011101 postfix/qmgr[27355]: 98D3C526D8: removed',
                          ],
              expectedData =>  {
                               from_address => 'jamor@dplanet.com',
                               message_id => '570359.711625741-sendEmail@localhost',
                               message_size => 914,
                               status => 'sent',
                               timestamp => "$year-Dec-28 04:50:42",
                               event => 'msgsent',
                               message => 'delivered via dovecot service',
                               to_address => 'macaco2@monos.org',
                               client_host_name => 'unknown',
                               relay => 'dovecot',
                               client_host_ip => '192.168.9.1',
                               message_type => 'received',
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





tratando enviar con auth cuando no es requerida:

Aug 25 09:21:34 intrepid postfix/smtpd[4270]: connect from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: setting up TLS connection from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: Anonymous TLS connection established from unknown[192.168.45.159]: TLSv1 with cipher DHE-RSA-AES256-SHA (256/256 bits)
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: lost connection after AUTH from unknown[192.168.45.159]
Aug 25 09:21:34 intrepid postfix/smtpd[4270]: disconnect from unknown[192.168.45.159]


tratando usar TSL cuando no está activo

Aug 25 09:35:53 intrepid postfix/smtpd[4161]: connect from unknown[192.168.45.159]
Aug 25 09:35:53 intrepid postfix/smtpd[4161]: lost connection after STARTTLS from unknown[192.168.45.159]
Aug 25 09:35:53 intrepid postfix/smtpd[4161]: disconnect from unknown[192.168.45.159]







