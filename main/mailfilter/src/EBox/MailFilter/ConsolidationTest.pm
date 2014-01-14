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

package EBox::MailFilter::ConsolidationTest;

use base 'EBox::Logs::Consolidate::Test';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More skip_all => 'FIXME';
use Test::More;
use Test::MockObject;

use Data::Dumper;

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
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 3.564,
              },
              {
               date => '2008-08-25 09:59:40',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 3.564
              },
              {
               date => '2008-08-25 10:01:06',
               event => 'INFECTED',
               action => 'Blocked',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits =>  '',
              },
              {
               date => '2008-08-25 10:01:06',
               event => 'INFECTED',
               action => 'Blocked',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => '',
              },
              {
               date => '2008-08-25 10:01:09',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 2.836
              },
              {
               date => '2008-08-25 10:01:09',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 2.836
              },
              {
               date => '2008-08-25 10:01:36',
               event => 'SPAM',
               action => 'Passed',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 6.786
              },
              {
               date => '2008-08-25 10:01:36',
               event => 'SPAM',
               action => 'Passed',
               from_address => 'spam@zentyal.org',
               to_address => 'macaco@monos.org',
               spam_hits => 6.786
              },
              {
               date => '2008-08-25 10:17:48',
               event => 'CLEAN',
               action => 'Passed',
               from_address => 'root@foo.bar.baz.zentyal.org',
               to_address => 'root@foo.bar.baz.zentyal.org',
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
