use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;

use lib '../../..';

use EBox::Global::TestStub;

use_ok 'EBox::Global::TestStub';

EBox::Global::TestStub::fake();

testStubsSetup();
modExistsTest();
getInstanceTest();
modInstanceTest();
changedTest();
clear();

sub testStubsSetup
{
    EBox::Global::TestStub::setModule('baboon', 'EBox::Baboon');

    MOCK_CLASS: {
        package EBox::Baboon;
        use base 'EBox::Module::Config';
        $INC{'EBox/Baboon.pm'} =1;
        sub _create
        {
            my ($class, @optParams) = @_;
            my $self = $class->SUPER::_create(name => 'baboon', @optParams);
            return $self;
        }
    }
}

sub modExistsTest
{
    my $global = EBox::Global->getInstance();
    ok $global->modExists('baboon'), 'Checking Global modExists method agaisnt a fake module';
}

sub modInstanceTest
{
    my $global = EBox::Global->getInstance();

    foreach my $n (0 .. 1) {
        my $baboonModule;
        lives_ok { $baboonModule = $global->modInstance('baboon') } 'modInstance';
        ok defined $baboonModule, 'Checking module returned by modInstance';
        isa_ok $baboonModule, 'EBox::Module::Config';
        isa_ok $baboonModule, 'EBox::Baboon';
    }
}

sub getInstanceTest
{
    my $global;

    foreach my $n (0 .. 1) {
        foreach my $readonly (0, 1) {
            lives_ok { $global = EBox::Global->getInstance($readonly) } 'EBox::Global::getInstance';
            isa_ok $global, 'EBox::Global';
        }
    }
}

sub changedTest
{
    my $baboonModule = EBox::Global->modInstance('baboon');
    defined $baboonModule or die "Cannot get a baboon module";
    my $global = EBox::Global->getInstance();

    $global->modChange('baboon');
    ok $global->modIsChanged('baboon'), 'Checking modChange and modIsChanged';
    $global->modRestarted('baboon');
    ok !$global->modIsChanged('baboon'), 'Checking modRestarted and modIsChanged';
}

sub clear
{
    EBox::Global::TestStub::clear();
}

1;
