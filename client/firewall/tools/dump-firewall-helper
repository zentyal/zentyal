#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Global;

my ($modName) = @ARGV;
defined $modName or die "You must supply the name of the module";

EBox::init();

my $mod = EBox::Global->modInstance($modName);
defined $mod or die "$modName don't exist";

$mod->can('firewallHelper') or die "$modName has not a firewallHelper method";

my $fw = $mod->firewallHelper();


my @rulesCat = qw(prerouting postrouting input externalInput output forward);
foreach my $cat (@rulesCat) {
  my @rules = @{  $fw->$cat()  };
  if (@rules) {
    print "\n$cat rules:\n";
    foreach (@rules) {
      print "\t$_\n";
    }
  }
  else {
    print "\n$cat : no rules\n";
  }
}


1;
