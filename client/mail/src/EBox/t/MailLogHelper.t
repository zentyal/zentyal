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

use Test::More qw(no_plan);
use Test::MockObject;
use Test::Exception;

use Data::Dumper;

my $dumpInsertedData = 1;

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
    my ($dbengine) = @_;

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


}

my @cases = (
             {
              # TSL SMTP connection
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
             },

             
            );



my $logHelper = new EBox::MailLogHelper();

foreach my $case (@cases) {
    my @lines = @{ $case->{lines} };

    my $dbEngine = newFakeDBEngine();
    lives_ok {
        foreach my $line (@lines) {
            $logHelper->processLine('fakeFile', $line, $dbEngine); 
        }
    } 'processing lines';

    checkInsert($dbEngine);
}



1;
