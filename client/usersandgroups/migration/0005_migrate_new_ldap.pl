#!/usr/bin/perl

#  Migration between gconf data version 4 and 5
#
#       This migration script takes care of adding the missing stuff after
#       migrating from the old 1.2 ldap structure
#
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Module::Base;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::Setup;

use Error qw(:try);

# Method: runGConf
#
#   Overrides <EBox::Migration::Base::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    my $mod = $self->{'gconfmodule'};
    if ($mod->configured()) {
        my $output = EBox::Sudo::root("slapcat -b 'cn=config' -s 'olcDatabase={1}hdb,cn=config'");
        my $aclLines = '';
        my @acls;
        push(@acls, 'to * by dn.exact=cn=localroot,cn=config manage by * break');
        my $acl = '';
        for my $line (@{$output}) {
            if ($line =~/olcAccess: {\d+}(.*)$/) {
                if ($acl ne '') {
                    $acl =~s/cn=admin,/cn=ebox,/;
                    push(@acls, $acl);
                    $acl = '';
                }
                $acl = $1;
            } elsif ($line =~/^ (.*)$/) {
                if ($acl ne '') {
                    $acl .= $1;
                }
            } else {
                if ($acl ne '') {
                    $acl =~s/cn=admin,/cn=ebox,/;
                    push(@acls, $acl);
                    $acl = '';
                }
            }
        }
        if ($acl ne '') {
            $acl =~s/cn=admin,/cn=ebox,/;
            push(@acls, $acl);
            $acl = '';
        }
        my $i = 0;
        for my $acl (@acls) {
            $aclLines .= "olcAccess: {$i}$acl\n";
            $i++;
        }
        #remove trailing end-line as otherwise the LDIF breaks
        chomp($aclLines);
        EBox::Module::Base::writeConfFileNoCheck(EBox::Config::tmp() .
            'slapd-master-upgrade.ldif',
            'usersandgroups/slapd-master-upgrade.ldif.mas',
            [
                'acls' => $aclLines,
            ]);
        EBox::Module::Base::writeConfFileNoCheck(EBox::Config::tmp() .
            'slapd-master-upgrade-ebox.ldif',
            'usersandgroups/slapd-master-upgrade-ebox.ldif.mas',
            [
                'dn' => 'dc=ebox',
                'password' => $mod->ldap()->getPassword()
            ]);
        EBox::Sudo::root("ldapadd -H 'ldapi://' -Y EXTERNAL -c -f " .
            EBox::Config::tmp() . "slapd-master-upgrade.ldif");
        EBox::Sudo::root("ldapadd -H 'ldapi://' -Y EXTERNAL -c -f " .
            EBox::Config::tmp() . "slapd-master-upgrade-ebox.ldif");
        my @mods = @{EBox::Global->modInstancesOfType('EBox::LdapModule')};
        for my $mod (@mods) {
            ($mod->name() eq 'users') and next;
            $mod->restartService();
        }
    } else {
        # remove the database so enabling it doesn't fail?
    }
    EBox::Sudo::root('chmod 700 /var/lib/ebox/conf/ssl');
    EBox::UsersAndGroups::Setup::createJournalsDirs();
}

# Main

EBox::init();

my $module = EBox::Global->modInstance('users');
my $migration = new EBox::Migration(
        'gconfmodule' => $module,
        'version' => 5,
);
$migration->execute();

1;
