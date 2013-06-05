#!/usr/bin/perl -w

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

# A module to test the <EBox::RemoteServices::Server::JobReceiver> class

use strict;
use warnings;

package EBox::RemoteServices::Server::JobReceiver::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::Config;
use EBox::Module::Config::TestStub;
use File::Slurp;
use Log::Log4perl qw(:easy);
use Test::Cmd;
use Test::Exception;
use Test::MockModule;
use Test::More qw(no_plan);

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub job_receiver_use_ok : Test(startup => 1)
{
    my ($self) = @_;

    $self->{jobDir} = '/tmp/job';
    mkdir($self->{jobDir});

    $self->{module} = new Test::MockModule('EBox::RemoteServices::Server::JobReceiver');
    $self->{module}->mock('JOBS_DIR', $self->{jobDir} . '/');
    $self->{module}->mock('INCOMING_DIR', $self->{jobDir} . '/incoming/');
    use_ok('EBox::RemoteServices::Server::JobReceiver')
      or die;
}

sub init_log : Test(startup)
{
    Log::Log4perl->easy_init($ERROR);
}

sub remove_job_dir : Test(shutdown)
{
    my ($self) = @_;

    system('rm -rf ' . $self->{jobDir});
}

sub test_run_job : Test(8)
{
    my ($self) = @_;

    throws_ok {
        EBox::RemoteServices::Server::JobReceiver->runJob();
    } 'EBox::Exceptions::MissingArgument',
      'Call without required arguments';

    my $jobId = 12321;
    my $args  = 'test1';
    my @coolParams = (jobId => $jobId,
                      script => qq{#!/bin/bash\necho "\$@"},
                      arguments => $args);

    my $jobDirPath = $self->{jobDir} . "/$jobId";
    my $cmd = new Test::Cmd(
        prog => "${jobDirPath}/script",
        workdir => '',
       );


    cmp_ok(EBox::RemoteServices::Server::JobReceiver->runJob(@coolParams),
           '==', 0, 'The job is ready to be run');

    ok( -d $jobDirPath, 'Directory was created correctly');
    ok( -x "$jobDirPath/script", 'Script is ready to execute');
    ok( -r "$jobDirPath/args", 'Arguments are ready to be passed');

    _testCmd($cmd, $jobDirPath, $args);

    $args = 'test1 test2';
    $coolParams[-1] = $args;
    cmp_ok(EBox::RemoteServices::Server::JobReceiver->runJob(@coolParams),
           '==', 1, 'The job is ready to be run after overwriting previous job');

    _testCmd($cmd, $jobDirPath, $args);
}

sub test_pull_status : Test(4)
{
    my ($self) = @_;

    throws_ok {
        EBox::RemoteServices::Server::JobReceiver->pullStatus();
    } 'EBox::Exceptions::MissingArgument',
      'Call without required argument';

    is_deeply(EBox::RemoteServices::Server::JobReceiver->pullStatus(23232),
              { 'status' => 'noexist', 'exitValue' => undef, 'stdout' => undef,
                'stderr' => undef }, 'Job does not exist');

    # Queue a job
    my $jobId = 12322;
    my $args  = 'test1';
    my @coolParams = (jobId => $jobId,
                      script => qq{#!/bin/bash\necho "\$@"},
                      arguments => $args);

    my $jobDirPath = $self->{jobDir} . "/$jobId";
    EBox::RemoteServices::Server::JobReceiver->runJob(@coolParams);

    is_deeply(EBox::RemoteServices::Server::JobReceiver->pullStatus($jobId),
              { 'status' => 'queued', 'exitValue' => undef, 'stdout' => undef,
                'stderr' => undef }, 'Job is on the queue');

    # Actually run it (mimetise runnerd)
    system("xargs -a $jobDirPath/args $jobDirPath/script > $jobDirPath/stdout 2> $jobDirPath/stderr");
    File::Slurp::write_file("$jobDirPath/exitValue", "0");
    unlink($self->{jobDir} . "/incoming/$jobId");

    is_deeply(EBox::RemoteServices::Server::JobReceiver->pullStatus($jobId),
              { 'status' => 'finished', 'exitValue' => 0, 'stdout' => $args . "\n",
                'stderr' => "" }, 'Job has been run');

}

sub _testCmd
{
    my ($cmd, $jobDirPath, $args) = @_;
    $cmd->run( args => scalar(File::Slurp::read_file("$jobDirPath/args")));
    my $out = $cmd->stdout();
    chomp($out);
    cmp_ok($out, 'eq', $args, 'The script was sucessfully');
}

1;

END {
    EBox::RemoteServices::Server::JobReceiver::Test->runtests();
}
