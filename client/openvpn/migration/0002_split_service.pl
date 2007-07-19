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
use EBox::Config;
use EBox::Sudo;

use Fatal qw(opendir readdir closedir);


sub runGConf
{
  my ($self) = @_;

  $self->_stopDaemons();

  $self->_updateGConf();
}


sub _updateGConf
{
  my ($self) = @_;
  my $openvpn = $self->{gconfmodule};

  # old service value now corresponf to userActive now
  my $oldService = $openvpn->get_bool('active');
  $openvpn->unset('active');
  $openvpn->set_bool('userActive', $oldService);
}



sub _stopDaemons
{
  my ($self) = @_;
  my $openvpn = $self->{gconfmodule};
  my $bin     = $openvpn->openvpnBin();
  my $killCmd = "/usr/bin/killall $bin";

  EBox::Sudo::root($killCmd);
}



EBox::init();
my $openvpn = EBox::Global->modInstance('openvpn');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $openvpn,
				     'version' => 1
				    );
$migration->execute();				     


1;
