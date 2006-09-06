# Description:
use strict;
use warnings;

use Test::More tests => 22;
use Test::Differences;
use Test::Exception;

use lib  '../..';

statTest();


sub statTest
{
    use EBox::Sudo::TestStub;
    EBox::Sudo::TestStub::fake();

    use EBox::TestStub;
    EBox::TestStub::fake();

    # inexistent file
    my $sudoStat;
    lives_ok {$sudoStat = EBox::Sudo::stat('/muchos/monos/salvajes') } 'Calling stat upon a inexistent file';
    ok !defined $sudoStat, "Checking tha return undef while stat called upon inexistent files";

    my @files = qw(./Sudo.t / /usr /bin/true /etc/passwd /dev/hda /dev/mem /dev/random /dev/tty0 /dev/snd/timer);
    foreach my $file (@files) {
    SKIP: {
	skip 2, "$file does not exist in your system. Skipping tests", unless -e $file;
	my @perlStat = stat $file;
	my $sudoStat = EBox::Sudo::stat($file);
	isa_ok $sudoStat, 'File::stat';
	my @sudoStatContents = ($sudoStat->dev, $sudoStat->ino, $sudoStat->mode, $sudoStat->nlink, $sudoStat->uid, $sudoStat->gid, $sudoStat->rdev, $sudoStat->size, $sudoStat->atime, $sudoStat->mtime, $sudoStat->ctime, $sudoStat->blksize, $sudoStat->blocks);


	eq_or_diff \@sudoStatContents, \@perlStat, "Comparing output of EBox::Sudo::stat with output of stat built-in upon $file";
      }
    }



}




1;
