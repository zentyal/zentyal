package EBox::MailFilter::ConsolidationTest;

use strict;
use warnings;

use base 'EBox::Logs::Consolidate::Test';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;
use Test::MockObject;

use Data::Dumper;

use lib '../../..';

use EBox::MailFilter;





sub modNameAndClass
{
    return ('mailfilter', 'EBox::MailFilter');
}


sub _standardDbContent
{
    return   [
              { 
               date => '2008-08-25 09:59:40', 
               event => 'CLEAN', 
               action => 'Passed', 
               from_address => 'spam@warp.es', 
               to_address => 'macaco@monos.org', 
               spam_hits => 3.564,
              },
              {
               date => '2008-08-25 09:59:40',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => 3.564
              },
              {
               date => '2008-08-25 10:01:06',
               event => 'INFECTED',
               action => 'Blocked',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits =>  '',
              },
              {
               date => '2008-08-25 10:01:06',
               event => 'INFECTED',
               action => 'Blocked',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => '',
              },
              {
               date => '2008-08-25 10:01:09',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => 2.836
              },
              {
               date => '2008-08-25 10:01:09',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => 2.836
              },
              {
               date => '2008-08-25 10:01:36',
               event => 'SPAM',
               action => 'Passed',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => 6.786
              },
              {
               date => '2008-08-25 10:01:36',
               event => 'SPAM',
               action => 'Passed',
               from_address => 'spam@warp.es',
               to_address => 'macaco@monos.org',
               spam_hits => 6.786
              },
              {
               date => '2008-08-25 10:17:48',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'root@intrepid.lan.hq.warp.es',
               to_address => 'root@intrepid.lan.hq.warp.es',
               spam_hits => 1.406
              },

             ];

}


sub consolidateTest : Test(4)
{
    my ($self) = @_;
    $self->runCases();
}


sub cases
{
    my @cases = (
                 {
                  name => 'simple maifilter case',
                  dbRows =>   __PACKAGE__->_standardDbContent(),
                  expectedConsolidatedRows => [
                                               {
                                                table => 'filter_traffic_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          clean => 5,
                                                          infected => 2,
                                                          spam => 2,
                                                         },

                                               },
                                    
                                              ]
                 },
                );

    return \@cases;

}


1;
