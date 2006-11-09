# Description:
use strict;
use warnings;

use Test::More tests => 32;
use Test::Differences;
use Test::Exception;
use Error qw(:try);
use File::Path;

use lib  '../..';

use EBox::Sudo::TestStub;
use EBox::TestStub;
use EBox::Config::TestStub;

# setup testdir
my $testDir = '/tmp/ebox.sudo.test';
File::Path::rmtree($testDir) if (-e $testDir);
mkdir $testDir;

EBox::TestStub::fake(); # to covert log in logfiel to msg into stderr
EBox::Config::TestStub::fake(tmp => $testDir);

exceptionTest();
rootWithoutExceptionTest();
statTest();
testFileTest();

sub exceptionTest
{

  EBox::Sudo::TestStub::fake();
  try {
    # it is important that the following command fails with a exit value of 1
    throws_ok  {  EBox::Sudo::root("test -f /")  } 'EBox::Exceptions::Sudo::Command', "Checking that command exception is raised when the command itself failed";
  }
  finally {
    EBox::Sudo::TestStub::unfake();
  };
}


sub rootWithoutExceptionTest
{
  EBox::Sudo::TestStub::fake();
  try {
    my $output ='macacos sonrientes';
    my $okCommand   = "perl -e 'print q{$output}; exit 0'";
    my $failCommand = "perl -e 'print q{$output}; exit 1'";
    
    my $expectedOutput = [$output];
    my $actualOutput = EBox::Sudo::rootWithoutException($okCommand);
    is_deeply $actualOutput, $expectedOutput;
    is_deeply EBox::Sudo::rootWithoutException($failCommand), $expectedOutput;
  }
  finally {
    EBox::Sudo::TestStub::unfake();
  };
}

sub statTest
{

    EBox::Sudo::TestStub::fake();

    # inexistent files
    lives_and (sub {is EBox::Sudo::stat('/muchos/monos/salvajes'), undef }, "Checking stat return undef while  called upon inexistent files in inexistent dir");
    lives_and (sub {ok not EBox::Sudo::stat('/inexistentfileBab')}, "Checking stat return undef while  called upon inexistent files in existent dir");

    my @files = qw(./Sudo.t / /usr /bin/true /etc/passwd /dev/hda /dev/mem /dev/random /dev/tty0 /dev/snd/timer);
    foreach my $file (@files) {
    SKIP: {
	skip "$file does not exist in your system. Skipping tests", 2, unless -e $file;
	my @perlStat = stat $file;
	my $sudoStat = EBox::Sudo::stat($file);
	isa_ok $sudoStat, 'File::stat';
	my @sudoStatContents = ($sudoStat->dev, $sudoStat->ino, $sudoStat->mode, $sudoStat->nlink, $sudoStat->uid, $sudoStat->gid, $sudoStat->rdev, $sudoStat->size, $sudoStat->atime, $sudoStat->mtime, $sudoStat->ctime, $sudoStat->blksize, $sudoStat->blocks);


	eq_or_diff \@sudoStatContents, \@perlStat, "Comparing output of EBox::Sudo::stat with output of stat built-in upon $file";
      }
    }

    
    dies_ok {   EBox::Sudo::stat("/", "/home") } 'Multiple stats not supported';
}


sub testFileTest
{
  dies_ok  { EBox::Sudo::fileTest('-z', '/')  } 'Trying testFile with a incorrect test';

  ok EBox::Sudo::fileTest('-r', '/'), "true test: EBox::Sudo::fileTest('-r', '/')";
  ok !EBox::Sudo::fileTest('-u', '/'), "false test: EBox::Sudo::fileTest('-u', '/')";
  ok EBox::Sudo::fileTest('-d', '/usr'), "true test: EBox::Sudo::fileTest('-d', '/usr')";
  ok !EBox::Sudo::fileTest('-f', '/usr'), "false test: EBox::Sudo::fileTest('-f', '/usr')";
  ok !EBox::Sudo::fileTest('-p', '/nowhere/inexistent-pipe'), "false test: EBox::Sudo::fileTest('-p', '/nowhere/inexistent-pipe')";
}

1;
