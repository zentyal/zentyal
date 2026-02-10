#!/usr/bin/perl

use strict;

use EBox;
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::ProgressIndicator;

use TryCatch;
use Cwd 'abs_path';
use Getopt::Long;
use Scalar::Util qw(blessed);

my @lines;
my $progressId;
my $progress;

sub getUsers
{
    EBox::init();
    my $samba = EBox::Global->modInstance('samba');

    my @allUsers = @{ $samba->users() };
    my @usersToExport = grep { $_->isInternal() ne 0 } @allUsers;
    my $total = scalar(@usersToExport);

    if ($progress) {
        $progress->setTotalTicks($total);
    }

    foreach my $u (@usersToExport) {
        if ($progress) {
            $progress->setMessage("Exporting " . $u->get('samAccountName'));
            $progress->notifyTick();
        }

        push @lines,
            $u->get('samAccountName') . ';'
          . $u->parent()->dn() . ';'
          . $u->get('givenName') . ';'
          . $u->get('sn') . ';'
          . $u->initials() . ';'
          . $u->displayName() . ';'
          . $u->description() . ';'
          . $u->mail() . ';'
          . 'password' . ';'
          . getUserGroups($u) . ";\n";
        print "Exporting " . $u->get('samAccountName') . " done...\n";
    }
    return @lines;
}

sub getUserGroups
{
    my($u) = @_;

    my $groups;

    foreach my $g(@ { $u-> groups(internal => 0, system => 1) } ) {
        $groups = $groups . $g->dn() . ':';
    }

    return substr($groups, 0, -1);
}

sub getPath
{
    my ($path) = @_;
    $path = abs_path($path);

    return $path;
}

sub writeCSV
{
    my ($p) = getPath(@_);

    # Check if directory exists and is writable
    my ($dir) = $p =~ m{^(.*/)};
    $dir = '.' unless $dir;
    unless (-d $dir && -w $dir) {
        die "Directory '$dir' does not exist or is not writable\n";
    }

    open( my $fh, '>', $p )
      or die "Could not create file '$p': $!\n";
    print $fh getUsers();
    close $fh;
    print "Users have been exported to file '$p'\n";

    return 1;
}

sub getParms
{
    my (@args) = @_;

    # Parse --progress-id if present (used by Zentyal web UI)
    GetOptions('progress-id=i' => \$progressId) or die "Bad options\n";

    if ($progressId) {
        $progress = EBox::ProgressIndicator->retrieve($progressId);
    }

    die "Usage: $0 <dest-file>\n" unless @ARGV == 1;

    print "Exporting users to file: $ARGV[0]\n";
    try {
        writeCSV( $ARGV[0] );
        if ($progress) {
            $progress->setAsFinished(0);
        }
    } catch ($e) {
        my $errorTxt = blessed($e) ? $e->text() : "$e";
        if ($progress) {
            $progress->setAsFinished(1, $errorTxt);
        }
        die $errorTxt;
    }
}

getParms(@ARGV);

