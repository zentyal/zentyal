#!/usr/bin/perl

# Migration between gconf data version 0 to 1
#
# In version 1, the access setting from CC is always passwordless
#

package EBox::Migration;

use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;

sub runGConf
{
    my ($self) = @_;

    my $rs = $self->{gconfmodule};

    if ( defined($rs->get_bool('AccessSettings/passwordless')) ) {
        $rs->set_bool('AccessSettings/passwordless', 1);
    }

}

EBox::init();

my $rsMod = EBox::Global->modInstance('remoteservices');
my $migration = __PACKAGE__->new(gconfmodule => $rsMod,
                                 version     => 1);

$migration->execute();
