# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::AntiVirus::Test;

use base 'EBox::Test::Class';

use EBox::Global::TestStub;
use EBox::Test;
use EBox::Test::RedisMock;
use EBox::TestStubs;
use Test::MockObject::Extends;
use Test::More;
use Test::Exception;
use Perl6::Junction qw(any);

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub setUpTestDir : Test(startup)
{
    my ($self) = @_;
    my $dir = $self->testDir();

    system("rm -rf $dir");
    mkdir($dir);
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub testDir
{
    return '/tmp/zentyal.antivirus.test';
}

sub av_isa_ok : Test
{
    use_ok('EBox::AntiVirus') or die;
}

sub freshclamEventTest : Test(17)
{
    my ($self) = @_;

    my $stateFile  = $self->testDir() . '/freshclam.state';
    system "rm -f $stateFile";
    $self->_fakeFreshclamStateFile($stateFile);

    my $clam = _clamavInstance();

    # deviant test
    dies_ok { $clam->notifyFreshclamEvent('unknownState')  } 'Bad event call';

    # first time test
    my $state_r = $clam->freshclamState();
    is_deeply($state_r, { date => undef, update => undef, error => undef, outdated => undef,  }, 'Checking freshclamState when no update has been done');

    my @allFields     = qw(update error outdated date);
    my @straightCases = (
        {
            params         => [ 'update'],
            activeFields   => ['update', 'date'],
        },
        {
            params => ['error'],
            activeFields => ['error', 'date'],
        },
        {
            params => ['outdated', '0.9a'],
            activeFields => ['outdated', 'date'],
        }
       );

    foreach my $case_r (@straightCases) {
        my @params = @{ $case_r->{params} };
        lives_ok { $clam->notifyFreshclamEvent(@params)  } "Calling to freshclamEvent with params @params";

        my $freshclamState = $clam->freshclamState();

        my $anyActiveField = any ( @{ $case_r->{activeFields} });
        foreach my $field (@allFields) {
            if ($field eq $anyActiveField) {
                like $freshclamState->{$field}, qr/[\d\w]+/, "Checking whether active field '$field' has a timestamp value or a version value";
            } else {
                cmp_ok($freshclamState->{$field}, '==', 0, "Checking the value of an inactive state field '$field'");
            }
        }

    }
}

sub _fakeFreshclamStateFile
{
    my ($self, $file) = @_;

    Test::MockObject->fake_module('EBox::MailFilter::ClamAV',
                                  freshclamStateFile => sub { return $file  },
                                 );

}

sub _clamavInstance
{
    my $redis = new EBox::Test::RedisMock();
    my $antivirus = EBox::AntiVirus->_create(redis => $redis);
    $antivirus = new Test::MockObject::Extends($antivirus);
    $antivirus->mock('freshclamStateFile', sub {
                         my ($self) = @_;
                         my $dir = EBox::AntiVirus::Test::testDir();
                         my $file = "$dir/freshclam.state";
                         return $file;
                     }
                    );

    return $antivirus;
}

1;
