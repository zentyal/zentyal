#!/usr/bin/perl

#  Migration between gconf data version X and Y
#
#       This migration script takes care of... TODO
#
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

# Method: runGConf
#
#   Overrides <EBox::MigrationBase::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    my $mod =$self->{'gconfmodule'};

    my @users = $mod->users();
    foreach my $user (@users) {
        if (not ($user->{password} =~ /\{SHA\}[0-9a-zA-Z\+\/]{27}=/)) {
            $mod->modifyUserPwd($user->{username}, $user->{password});
        }
    }
}

# Main

EBox::init();

my $module = EBox::Global->modInstance('users');
my $migration = new EBox::Migration( 
        'gconfmodule' => $module,
        'version' => 2,
        );
$migration->execute();

1;
