#!/usr/bin/perl
# script to invoke the learning method without using the web UI
use strict;
use warnings;


use EBox;
use EBox::Global;
use File::Temp;
use Error qw(:try);


EBox::init();

my ($account, $isSpam, $mboxFile) = @ARGV;
defined $account  or die;
defined $isSpam   or die;

my $fh;
if (not defined $mboxFile) {
    # read a mbox file from stdin
    my @contents = <STDIN>;
    $fh = File::Temp->new(TEMPLATE => 'salearn-mbox-XXXX', DIR => '/tmp');
    print $fh @contents;
    $mboxFile = $fh->filename();
    @contents = ();

    # assure that is readable by amavis user
    EBox::Sudo::root("chown amavis.amavis $mboxFile");
}

# we will use a red only instance bz we dont want to use any changes in the
# configuration that arent commmited
my $global = EBox::Global->getInstance(1);

my $mailfilter = $global->modInstance('mailfilter');
$mailfilter or 
    die "Cannot get mailfilter module instance";
$mailfilter->configured() or
    die 'Mail filter module is not configured. Enable it at least one time to configure it';



my @learnParams = (
                   username => $account,
                   input => $mboxFile,
                   isSpam => $isSpam,

);

try {
    $mailfilter->antispam()->learn(@learnParams);
} otherwise {
 my $ex = @_;
 print "$ex";
};


1;
