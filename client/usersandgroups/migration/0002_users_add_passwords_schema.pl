#!/usr/bin/perl

#  Migration between gconf data version X and Y
#
#       This migration script takes care of adding the passwords.schema
#       file if the module has already been enabled
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
use EBox::UsersAndGroups;

use Error qw(:try);

# Method: runGConf
#
#   Overrides <EBox::MigrationBase::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    my $mod = $self->{'gconfmodule'};

    if ($mod->configured()) {
        # FIXME: fix this for all cases
        EBox::Sudo::root('cp /usr/share/ebox-usersandgroups/passwords.schema /etc/ldap/schema/');
        $mod->writeLDAPConf();
        EBox::Sudo::root('invoke-rc.d slapd restart');
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
