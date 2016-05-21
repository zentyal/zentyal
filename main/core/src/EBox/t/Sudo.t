use strict;
use warnings;

use Test::More tests => 45;
use Test::Differences;
use Test::Exception;
use TryCatch;
use File::Path;

use lib  '../..';

use EBox::Sudo;

use EBox::TestStub;
use EBox::Config::TestStub;

# setup testdir
my $testDir = '/tmp/ebox.sudo.test';
File::Path::rmtree($testDir) if (-e $testDir);
mkdir $testDir;

# dont run sudo really so we can test this with a normal user
my $fakeSudo   = '';
my $fakeStderr =  "$testDir/stderr";
*EBox::Sudo::SUDO_PATH = \$fakeSudo;
*EBox::Sudo::STDERR_FILE = \$fakeStderr;

EBox::TestStub::fake(); # to covert log in logfiel to msg into stderr
EBox::Config::TestStub::fake(tmp => $testDir);

# run the tests
exceptionTest();
rootTest();
rootWithoutExceptionTest();
statTest();
testFileTest();
commandTest();

sub rootTest
{
    my $touchFile = '/tmp/lulu';

    lives_ok {
        EBox::Sudo::root("touch $touchFile")
    } 'root command without failure';

    system "ls $testDir/*.cmd";
    ok $? != 0, 'checking that not cmd file was left behind';

    # same test but with exception
    dies_ok {
        EBox::Sudo::root("ls /inexistent/*");
    } 'root comamnd with failure';
    system "ls $testDir/*.cmd";
    ok $? != 0, 'checking that not cmd file was left behind after root with exception';

    unlink $touchFile;
}

sub exceptionTest
{
    lives_ok  {
        EBox::Sudo::root("test -d /")
      } "Checking that a correct command does nto raise exception";

    # it is important that the following command fails with a exit value of 1
    throws_ok  {
        EBox::Sudo::root("test -f /")
      } 'EBox::Exceptions::Sudo::Command', "Checking that command exception is raised when the command itself failed";
}

sub rootWithoutExceptionTest
{

    my $output = 'macacos sonrientes';
    my $okCommand   = "perl -e 'print q{$output}; exit 0'";
    my $failCommand = "perl -e 'print q{$output}; exit 1'";

    my $expectedOutput = [$output];
    my $actualOutput = EBox::Sudo::rootWithoutException($okCommand);
    is_deeply $actualOutput, $expectedOutput;
    is_deeply EBox::Sudo::rootWithoutException($failCommand), $expectedOutput;
}

sub commandTest
{
    my $output = 'macacos sonrientes';
    my $errorOutput = 'error';

    my $okCommand   = "perl -e 'print q{$output}; exit 0'";
    my $failCommand = "perl -e 'print q{$output}; print STDERR q{$errorOutput} ; exit 1'";

    my $expectedOutput = [$output];
    my $expectedErrorOutput = [$errorOutput];

    my $actualOutput;
    lives_ok { $actualOutput = EBox::Sudo::command($okCommand) } 'Invoking a succeeding command with EBox::Sudo::command';
    is_deeply $actualOutput, $expectedOutput, 'Checking output of succeeding command';

    my $ex;

    my $testName = "Invoking a command which fails with EBox::Sudo::command";
    try {
        EBox::Sudo::command($failCommand);
        fail $testName;
    } catch ($e) {
        $ex = $e;
        pass $testName;
    }

    isa_ok($ex, 'EBox::Exceptions::Command');
    is $ex->cmd(), $failCommand, 'Checking command attribute of command wich fails';
    is_deeply $ex->output(), $expectedOutput, 'Checking output of command wich fails';
    is_deeply $ex->error(), $expectedErrorOutput, 'Checking error output of command wich fails';
    is $ex->exitValue(), 1, 'Checking exit value of command wich fails';
}


sub statTest
{
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
