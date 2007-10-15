#!/usr/bin/perl

#  Migration between gconf data version 1 and 2
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;



sub runGConf
{
  my ($self) = @_;

  $self->_migrateDomains();
  $self->_migrateContentFilterThreshold();
}



sub _migrateDomains
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  foreach my $confDir ( $squid->all_dirs('DomainFilter/keys') ) {
    my $allowKey  = "$confDir/allowed";
    my $policyKey = "$confDir/policy";

    my $oldAllowed = $squid->get_bool($allowKey);
    $squid->unset($allowKey);

    my $policy = $oldAllowed ? 'allow' : 'deny';
    $squid->set_string($policyKey, $policy);
  }
}


sub _migrateContentFilterThreshold
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  
  my $oldThresholdKey = 'GeneralSettings/contentFilterThreshold';
  my $oldThreshold    = $squid->get_string($oldThresholdKey);

  if (defined $oldThreshold) {
    my $newThresholdKey = 'ContentFilterThreshold/contentFilterThreshold';
    $squid->set_string($newThresholdKey, $oldThreshold);
  }
}


EBox::init();
my $squid = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $squid,
				     'version' => 2,
				    );
$migration->execute();				     


1;
