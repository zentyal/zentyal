use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

use lib '../../../..';
use EBox::TestStub;
EBox::TestStub::fake();
use EBox::Exceptions::Command;

use_ok ('EBox::Exceptions::Sudo::Command');

liskovTest();

sub liskovTest
{
    my $sudoCommandException;
    my $commandException;

    my %attributes = (
        cmd => 'test cmd',
        output => [qw(output1 output2)],
        error => [qw(error1)],
        exitValue => 1
    );

    lives_ok {
        $commandException = new EBox::Exceptions::Command (%attributes);
        $sudoCommandException = new EBox::Exceptions::Sudo::Command (%attributes);
    } 'Creating EBox::Exceptions::Command and EBox::Exceptions::Sudo::Command instances';

    isa_ok($sudoCommandException, 'EBox::Exceptions::Command');
    can_ok($sudoCommandException, keys %attributes);

    while (my($attr, $value ) = each %attributes) {
        my $cmdAttrSub = $commandException->can($attr);
        my $sudoCmdAttrSub = $sudoCommandException->can($attr);
        is $sudoCmdAttrSub->($sudoCommandException), $cmdAttrSub->($commandException), 'Checking attribute $attr is handled in EBox::Exceptions::Sudo::Command like in EBox::Exceptions::Command';
    }
}

1;
