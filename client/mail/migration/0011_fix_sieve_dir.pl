#!/usr/bin/perl
#
# Move old sieve dir /var/sieve-scripts to new location
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

sub runGConf
{
    my ($self) = @_;

    my $oldDir = '/var/sieve-scripts';
    my $newDir = '/var/vmail/sieve';

    my $existsOld = EBox::Sudo::fileTest('-d', $oldDir);
    if (not $existsOld) {
        # no old directoy, nothing to migrate
        return;
    }

    EBox::Sudo::root("mv  $oldDir/* $newDir");
    EBox::Sudo::root("rm -rf $oldDir");
}




EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 11
        );
$migration->execute();
