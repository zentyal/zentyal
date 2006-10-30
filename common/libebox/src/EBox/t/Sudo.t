# Description:
use strict;
use warnings;

use Test::More tests => 26;
use Test::Differences;
use Test::Exception;
use Error qw(:try);

use lib  '../..';

use EBox::Sudo::TestStub;
use EBox::TestStub;

EBox::TestStub::fake(); # to covert log in logfiel to msg into stderr
exceptionTest();
rootWithoutExceptionTest();
statTest();


sub exceptionTest
{
  diag "The following check assummes that the current user is not in the sudoers file";
  throws_ok {  EBox::Sudo::root("/bin/ls /")  } 'EBox::Exceptions::Sudo::Wrapper', "Checking that Wrapper exception is raised when sudo itself failed";

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

    # inexistent file
    lives_and (sub {is EBox::Sudo::stat('/muchos/monos/salvajes'), undef }, "Checking stat return undef while  called upon inexistent files");


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




1;
