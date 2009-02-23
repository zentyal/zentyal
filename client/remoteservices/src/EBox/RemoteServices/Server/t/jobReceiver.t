#!/usr/bin/perl -w

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

# A module to test the <EBox::RemoteServices::Server::JobReceiver> class

use strict;
use warnings;

use EBox::Config;
use File::Slurp;
use Test::Cmd;
use Test::Exception;
use Test::More tests => 9;

BEGIN {
    diag('A unit test for EBox::RemoteServices::Server::JobReceiver');
    use_ok('EBox::RemoteServices::Server::JobReceiver')
      or die;
}

sub _testCmd
{
    my ($cmd, $jobDirPath, $args) = @_;
    $cmd->run( args => scalar(File::Slurp::read_file("$jobDirPath/args")));
    my $out = $cmd->stdout();
    chomp($out);
    cmp_ok($out, 'eq', $args, 'The script was sucessfully');
}

my $jobId = 12321;
my $args  = 'test1';
my @coolParams = (jobId => $jobId,
                  script => qq{#!/bin/bash\necho "\$@"},
                  arguments => $args);
my $jobDirPath = EBox::Config::conf() . "remoteservices/jobs/$jobId/";
my $cmd = new Test::Cmd(
    prog => "${jobDirPath}script",
    workdir => '',
   );

throws_ok {
    EBox::RemoteServices::Server::JobReceiver->runJob();
} 'EBox::Exceptions::MissingArgument',
  'Call without required arguments';

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

system("rm -rf $jobDirPath");
