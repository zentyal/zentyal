#!/usr/bin/perl

#  Migration between  data version 1 and 2
#
#  Changes: in case that the mailfitler module is enabled the antivirus module
#  msut be automatically enabled
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
# use EBox::Config;
# use EBox::Sudo;



sub runGConf
{
  my ($self) = @_;

  my $mailfilter = EBox::Global->modInstance('mailfilter');
  if (not $mailfilter->isEnabled()) {
      # nothing to do then..
      return;
  }

  my $antivirus = $self->{gconfmodule};
  unless ( $antivirus->configured() ) {
      $antivirus->setConfigured(1);
      $antivirus->enabledActions();
      $antivirus->save();
  }
  unless ( $antivirus->isEnabled() ) {
      $antivirus->enableService(1);
      $antivirus->save();
  }

}





EBox::init();
my $antivirus = EBox::Global->modInstance('antivirus');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $antivirus,
                                     'version' => 1
                                    );
$migration->execute();                               


1;
