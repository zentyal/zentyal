#!/usr/bin/perl

#  Migration between gconf data version
#
#  This is intended to add mailfilter account to domains created with previous
#  verisons of mailfilter
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

sub runGConf
{
  my ($self) = @_;

  # if module is not configured we will add the clamav user to the group p3scan
  # in the module configuration stage
  my $mailfilter = $self->{gconfmodule};
  return if not $mailfilter->configured(); 


  EBox::Sudo::root('addgroup clamav p3scan');
}

EBox::init();
my $mailfilter = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $mailfilter,
                                     'version' => 3,
                                    );
$migration->execute();          		     


1;
