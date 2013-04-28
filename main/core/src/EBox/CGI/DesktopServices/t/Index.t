# Copyright (C) 2013 Zentyal S.L.
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

#use Test::More tests => 13;
use Test::More skip_all => 'FIXME in Jenkins';
use Test::Output;
use Test::Exception;

use lib '../../../..';
use EBox::CGI::DesktopServices::Index;

use EBox::TestStubs;
use EBox::Test::CGI;

EBox::TestStubs::activateTestStubs();
setupFakeModules();
JSONReplyTest();
validateRefererTest();

sub JSONReplyTest
{
    my $cgi = EBox::CGI::DesktopServices::Index->new();

    my $jsonHeader = $cgi->cgi()->header(-charset=>'utf-8',
                                         -type => 'application/JSON',
                                        );
    my @cases = (
        {
            desc   => 'no url',
            url => '',
            expected => '[]',
        },
        {
            desc   => 'bad url',
            url => 'badScript',
            expected => '[]',
        },
        {
            desc   => 'inexistent module',
            url => 'inexistentModule/subscriptionDetails/',
            expected => '[]',
        },
        {
            desc   => 'inexistent action',
            url => 'serviceProviderA/inexistent/',
            expected => '[]',
        },
        {
            desc   => 'desktop action which returns undef',
            url => 'serviceProviderA/undefAction/',
            expected => '[]',
        },
        {
            desc   => 'correct desktop action',
            url => 'serviceProviderB/details/',
            expected => '{"users":["user1","user2"],"id":433,"type":"professional"}',
        },
       );

    foreach my $case (@cases) {
        my $url = $case->{url};
        $ENV{script} = $case->{url};
        my $desc =  $case->{desc};

        my $expected = $jsonHeader;
        $expected .=  $case->{expected};

        lives_ok {
            $cgi->_process();
        } "Checking that CGI process the url '$url' without dying";
        stdout_is {
            $cgi->_print
        } $expected, "Checking JSON output for case $desc";
    }
}

sub setupFakeModules
{
    EBox::TestStubs::fakeModule(
         name => 'noServiceProvider',
         subs => [
             desktopActions => sub {
                 subscriptionDetails => sub { die 'should not be called' }
             }
            ]
        );

    EBox::TestStubs::fakeModule(
         name => 'serviceProviderA',
         isa => ['EBox::Desktop::ServiceProvider'],
         subs => [
             desktopActions => sub {
                        return {
                            undefAction =>  sub {return undef  }
                           }
                    }
            ]
        );

    EBox::TestStubs::fakeModule(
         name => 'serviceProviderEmpty',
         isa => ['EBox::Desktop::ServiceProvider'],
         subs => [
             desktopActions => sub {
                 return {}
             }
            ]
        );

    EBox::TestStubs::fakeModule(
         name => 'serviceProviderB',
         isa => ['EBox::Desktop::ServiceProvider'],
         subs => [
             desktopActions => sub {
                 return {
                     details => sub {
                         return {
                             type => 'professional',
                             id => 433,
                             users => ['user1', 'user2']
                            }
                     }

                    }
             }
            ]
        );
}

sub validateRefererTest
{
    my $cgi = EBox::CGI::DesktopServices::Index->new();

    my $hostname = '192.168.45.12';
    my $referer = '45.33.33.12';
    my $url     =  'serviceProviderB/details/';

    $ENV{HTTP_HOST} = $hostname;
    $ENV{HTTP_REFERER} = $referer;
    $ENV{script} = $url;

    # setting postdata parameter from POST request
    EBox::Test::CGI::setCgiParams($cgi, 'POSTDATA' => '');
    lives_ok {
        $cgi->_validateReferer();
    } 'Checking that CGI services is not affected by HTTP referer';
}


1;
