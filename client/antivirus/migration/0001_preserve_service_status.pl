#!/usr/bin/perl

#  Migration between  data version 1 and 2
#
#  Changes: in case that the mailfitler module is enabled the antivirus module
#  msut be automatically enabled
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
# use EBox::Config;
# use EBox::Sudo;



sub runGConf
{
  my ($self) = @_;

  my $mailfilter = $self->_moduleService('mailfilter');
  my $squid = $self->_moduleService('squid');

  if (not ($mailfilter or $squid)) {
      # no needed antivirus activation
      return;
  }

  my $antivirus = $self->{gconfmodule};
  unless ( $antivirus->configured() ) {
      $antivirus->setConfigured(1);
      $antivirus->enableActions();
      $antivirus->save();
  }
  unless ( $antivirus->isEnabled() ) {
      $antivirus->enableService(1);
      $antivirus->save();
  }


  foreach my $mod ($mailfilter, $squid) {
      $mod or
          next;

      $mod->setAsChanged();
      $mod->save();
  }

}



sub _moduleService
{
    my ($self, $modName) = @_;
    my $mod = EBox::Global->modInstance($modName);
    if (not $mod) {
        return 0;
    }

    if (not $mod->isEnabled()) {
        return 0;
    }

    return $mod;
}



EBox::init();
my $antivirus = EBox::Global->modInstance('antivirus');
my $migration = new EBox::Migration(
                                     'gconfmodule' => $antivirus,
                                     'version' => 1
                                    );
$migration->execute();


1;
