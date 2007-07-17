# script to invoke the learning method without using the web UI
use strict;
use warnings;


use EBox;
use EBox::Global;

EBox::init();

my ($mboxFile, $isSpam) = @ARGV;
defined $isSpam   or die;
defined $mboxFile or die;


my $mailfilter = EBox::Global->modInstance('mailfilter');
$mailfilter or die ;



my @learnParams = (
		   input => $mboxFile,
		   format=> 'mbox',
		   isSpam => $isSpam,

);

$mailfilter->antispam()->learn(@learnParams);


1;
