package EBox::Test::Mock::Sudo;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;

# XXX Currently i see not way for mocking EBox::Sudo::sudo
# XXX there are unclaer situation with comamnds containig ';' but this is also de case of EBox::Sudo

my $mockedSudoModule;

sub mock
{
    $mockedSudoModule = new Test::MockModule ('EBox::Sudo');
    $mockedSudoModule->mock('root', \&_mockedRoot);
}

sub unmock
{
  defined $mockedSudoModule or die "Module was not mocked";
  $mockedSudoModule->unmock_all();
}


sub _mockedRoot
{
    my ($cmd) = @_;

    my @output = `$cmd`;
    unless($? == 0) {
	_rootCommandException($cmd);
    }
    return \@output;
}



sub _rootCommandException
{
    my ($cmd) = @_;
    throw EBox::Exceptions::Internal("Root command $cmd failed");
}


1;
