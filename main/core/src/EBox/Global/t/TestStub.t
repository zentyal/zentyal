use strict;
use warnings;

use Test::More tests => 19;
use Test::Exception;

use lib '../../..';

use EBox::Global::TestStub;


EBox::Global::TestStub::fake();

testStubsSetup();
modExistsTest();
getInstanceTest();
modInstanceTest();
changedTest();
clear();

sub testStubsSetup
{
    EBox::Global::TestStub::setModule('auditAlias', 'EBox::AuditLogging');
}

sub modExistsTest
{
    my $global = EBox::Global->getInstance();
    ok $global->modExists('auditAlias'), 'Checking Global modExists method agaisnt a fake module';
}

sub modInstanceTest
{
    my $global = EBox::Global->getInstance();

    foreach my $n (0 .. 1) {
        my $auditAliasModule;
        lives_ok { $auditAliasModule = $global->modInstance('auditAlias') } 'modInstance';
        ok defined $auditAliasModule, 'Checking module returned by modInstance';
        isa_ok $auditAliasModule, 'EBox::Module::Config';
        isa_ok $auditAliasModule, 'EBox::AuditLogging';
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
    my $auditAliasModule = EBox::Global->modInstance('auditAlias');
    defined $auditAliasModule or die "Cannot get a auditAlias module";
    my $global = EBox::Global->getInstance();

    $global->modChange('auditAlias');
    ok $global->modIsChanged('auditAlias'), 'Checking modChange and modIsChanged';
    $global->modRestarted('auditAlias');
    ok !$global->modIsChanged('auditAlias'), 'Checking modRestarted and modIsChanged';
}

sub clear
{
    EBox::Global::TestStub::clear();
}




1;
