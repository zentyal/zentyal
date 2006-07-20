# Description:
use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Differences;

use lib  '../..';

statTest();


sub statTest
{
    use EBox::Sudo::TestStub;
    EBox::Sudo::TestStub::fake();

    my @files = qw(/ /usr /bin/true /etc/passwd /dev/hda);
    foreach my $file (@files) {
	my @perlStat = stat $file;
	my $sudoStat = EBox::Sudo::stat($file);
	isa_ok $sudoStat, 'File::stat';
	my @sudoStatContents = ($sudoStat->dev, $sudoStat->ino, $sudoStat->mode, $sudoStat->nlink, $sudoStat->uid, $sudoStat->gid, $sudoStat->rdev, $sudoStat->size, $sudoStat->atime, $sudoStat->mtime, $sudoStat->ctime, $sudoStat->blksize, $sudoStat->blocks);
	
	eq_or_diff \@sudoStatContents, \@perlStat, "Comparing output of EBox::Sudo::stat with output of stat built-in";


    }

    # inexistent file
    my $sudoStat = EBox::Sudo::stat('/muchos/monos/salvajes');
    ok !defined $sudoStat, "Checking tha return undef while stat called upon inexistent files";

}




1;
