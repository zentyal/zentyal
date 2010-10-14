#!perl
use strict;
use warnings;
use Win32::TieRegistry(Delimiter=>"#", ArrayValues=>0);

$Registry->Delimiter("/");      
my $APPDATA= $Registry->{"CUser/Volatile Environment/APPDATA"} 
    or die "Error: $^E\n";

my $USER = $ENV{USERNAME};
my $SERVER = 'zentyal.com';

open (T_ACCOUNT, '<.\templates\pidgin\accounts.xml')
    or die "Error: $^E\n";
my $account = join ("",<T_ACCOUNT>);
$account =~ s/USERNAME/$USER/g;
$account =~ s/EBOXDOMAIN/zentyal/g;
$account =~ s/EBOXSERVER/$SERVER/g;

open (T_BLIST, '<.\templates\pidgin\blist.xml')
    or die "Error: $^E\n";
my $blist = join ("", <T_BLIST>);
$blist =~ s/USERNAME/$USER/g;
$blist =~ s/EBOXDOMAIN/ebox/g;

print $account;

open (ACCOUNT, '>'. $APPDATA . '\.purple\accounts.xml') or die "Error: $^E\n";
print ACCOUNT $account;

open (BLIST, '>' .$APPDATA . '\.purple\blist.xml') or die "Error: $^E\n";
print BLIST $blist;
