#!/usr/bin/perl
#
# Add default vlaues for the following fields:
#        - postmastr address
#
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

use constant BOUNCE_ADDRESS_KEY => 'SMTPOptions/bounceReturnAddress';
use constant BOUNCE_ADDRESS_DEFAULT => 'noreply@example.com';

sub runGConf
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};
    my $bounceAddress = $mail->get_string(BOUNCE_ADDRESS_KEY);
    if (not $bounceAddress) {
        $mail->set_string(BOUNCE_ADDRESS_KEY, BOUNCE_ADDRESS_DEFAULT);
    }

}



EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 9,
        );
$migration->execute();
