#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

# Method: runGConf
#
# Overrides:
#
#     <EBox::Migration::Base::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    if ( $self->{gconfmodule}->configured() ) {
        EBox::Sudo::root('chmod g+w /etc/bind');
    }

}

EBox::init();

my $dnsMod = EBox::Global->modInstance('dns');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dnsMod,
    'version' => 4
);
$migration->execute();
