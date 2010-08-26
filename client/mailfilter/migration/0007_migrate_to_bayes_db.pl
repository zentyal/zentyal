#!/usr/bin/perl
#
# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# This is a migration script to add a service and firewall rules
# for the Zentyal mail system
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Sudo;
use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

use constant DB_USER => 'amavis';

sub runGConf
{
    my ($self) = @_;
    my $mod = $self->{gconfmodule};
    if (not $mod->configured()) {
        # enable script would take care of all of this
        return;
    }

    $self->_createDatabase();
    $self->_migrateDatabase();
}

sub _createDatabase
{
    my ($self) = @_;
    my $cmd = '/usr/share/ebox-mailfilter/ebox-mailfilter-sql update';
    EBox::Sudo::root($cmd);
}


sub _migrateDatabase
{
    my ($self) = @_;

    # check that exists a old database
    my $dbPath = EBox::Config::home() . '/.spamassassin';
    if (not -d $dbPath) {
        # no old database
        return;
    }

    # backup old database
    my $backupFile = '/tmp/bayes.backup';
    # to better execute backup command
    print "Dumping old bayes database\n";
    EBox::Sudo::root("chown -R ebox.ebox $dbPath");
    my $dumpCmd =
          "sa-learn --siteconfigpath=/dev/null  --local --dbpath=$dbPath  --backup > $backupFile";
    system $dumpCmd;

    # we had to overwrite the SA config otherwise it will fail the rsotre
    # process i am not very fond of this protion of the migration bz is fragile,
    # changes in the API could broke it easily
    my $mailfilter = EBox::Global->modInstance('mailfilter');
    $mailfilter->antispam()->writeConf();

    # restore old database
    print "Importing old bayes database to PostgreSQL database. This will take several minutes. Please wait\n";
    EBox::Sudo::root('chown ' . DB_USER . '.' . DB_USER . " $backupFile");
    my $restoreCmd =
       'su ' . DB_USER . qq{ -c'sa-learn --local -p /etc/spamassassin/local.cf --restore $backupFile'};
    EBox::Sudo::root($restoreCmd);

    # remove old database and its backup
    EBox::Sudo::root("rm -r $dbPath $backupFile");
}



EBox::init();

my $mailfilterMod = EBox::Global->modInstance('mailfilter');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailfilterMod,
        'version' => 7,
        );
$migration->execute();
1;


