#!/usr/bin/perl

#  Migration between gconf data version 1 and 2
#
#   gconf changes: we must remove the values of the CongigureLogTableModel to
#  allow his regenration with the new column 'lifeTime' in the next call of the
#  rows method

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



sub runGConf
{
  my ($self) = @_;

  # add default values to the ConfigureLogTable's keys gconf branch 
  my $log = $self->{gconfmodule};

  
  foreach my $confDir ($log->all_dirs('configureLogTable/keys')) {
    my $lifeTimeKey = "$confDir/lifeTime";
    $log->set_string($lifeTimeKey, 0);
  }
}



EBox::init();
my $logs = EBox::Global->modInstance('logs');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $logs,
				     'version' => 1
				    );
$migration->execute();				     


1;
