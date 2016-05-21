#!/usr/bin/perl
# script to invoke the learning method without using the web UI
# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;


use EBox;
use EBox::Global;
use File::Temp;
use TryCatch;


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
} catch {
    my $ex = @_;
    print "$ex";
}

1;
