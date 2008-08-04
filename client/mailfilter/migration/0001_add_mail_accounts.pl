#!/usr/bin/perl

#  Migration between gconf data version 1 and 2
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
use EBox::Config;
use EBox::Sudo;

sub runGConf
{
  my ($self) = @_;

  # if module is not configured we will add the accounts in the configuration stage
  my $mailfilter = $self->{gconfmodule};
  return if not $mailfilter->configured(); 

  # run ebox-mailfilter-ldap to add the user accounts and the mail accounts to
  # the vdomains
  EBox::Sudo::root('/usr/share/ebox-mailfilter/ebox-mailfilter-ldap update');
}

EBox::init();
my $mailfilter = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $mailfilter,
                                     'version' => 1
                                    );
$migration->execute();          		     


1;
