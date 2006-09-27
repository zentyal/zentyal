package EBox::Sudo::TestStub;
# Description:
# 
use strict;
use warnings;

#use Test::MockModule;
use EBox::Sudo;

# XXX There are problems with symbol imporation and Test::MockModule
# until we found a solution we will use a brute redefiniton
# XXX Currently i see not way for mocking EBox::Sudo::sudo
# XXX there are unclear situation with comamnds containig ';' but this is also de case of EBox::Sudo

#my $mockedSudoModule = undef;

my $oldRootSub = undef;
my $oldRootWithoutExceptionSub = undef;

sub fake
{
    $oldRootSub = \&EBox::Sudo::root if !defined $oldRootSub;
    $oldRootWithoutExceptionSub =  \&EBox::Sudo::rootWithoutException if !defined $oldRootWithoutExceptionSub;

    no warnings 'redefine';
    my $redefinition = '
    sub EBox::Sudo::root
    {
	return EBox::Sudo::TestStub::_fakedRoot(@_);
    }
    sub EBox::Sudo::rootWithoutException
    {
	return EBox::Sudo::TestStub::_fakedRootWithoutException(@_);
    }
     ';

    eval $redefinition;
   if ($@) {
    throw EBox::Exceptions::Internal ("Error while redifinition of root for test purposes: $@");
  }

}


# XXX fix:  restores behaviour but no implementation 
sub unfake
{
    defined $oldRootSub or die "Module was not mocked";


    no warnings 'redefine';
    my $redefinition = ' sub EBox::Sudo::root
     {
 	return $oldRootSub->(@_);
     }
      sub EBox::Sudo::rootWithoutException
     {
 	return $oldRootWithoutExceptionSub->(@_);
     }
      ';

    eval $redefinition;
    if ($@) {
	throw EBox::Exceptions::Internal ("Error while redifinition of root for test purposes: $@");
    }

}


sub _fakedRoot
{
    my ($cmd) = @_;

    my @output = `$cmd`;
    unless($? == 0) {
         my $error = "@output\n$!";
	_rootCommandException($cmd, $error);
    }
    return \@output;
}


sub _fakedRootWithoutException
{
    my ($cmd) = @_;

    my @output = `$cmd`;
    return \@output;
}


sub _rootCommandException
{
    my ($cmd, $error) = @_;
    throw EBox::Exceptions::Internal("(Mocked EBox::Sudo) Root command $cmd failed. Comand output: $error");
}



1;
