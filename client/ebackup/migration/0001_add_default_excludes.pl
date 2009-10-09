#!/usr/bin/perl

#
#   This migration script adds the default directories
#   that will be excluded
#

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Socket;


sub runGConf
{
    my ($self) = @_;

    my @defaultExcludes = ('/dev', '/proc', '/sys', '/mnt', '/media');
    my @defaultIncludes = ('/');
    my $model = $self->{gconfmodule}->model('RemoteExcludes');
    for my $exclude (@defaultExcludes) {
        $model->addRow( type => 'exclude_path', target => $exclude );
    }
    for my $include (@defaultIncludes) {
        $model->addRow( type => 'include', target => $include );
    }
}

EBox::init();

my $ebackup = EBox::Global->modInstance('ebackup');
my $migration = new EBox::Migration(
    'gconfmodule' => $ebackup,
    'version' => 1,
);
$migration->execute();
