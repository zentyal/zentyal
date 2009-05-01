#!/usr/bin/perl

use warnings;
use strict;

my $TASK_FILE = 'tasks.list';
my $PACKAGE_FILE = 'packages.list';
my $SELECTION_FILE = 'selection';
my $INSTALL_FILES_PATH = '/var/tmp';

my $TASK_TITLE = 'Select eBox tasks to install';
my $PACKAGE_TITLE = 'Select eBox packages to install';

my $WHIPTAIL_ARGS = '--backtitle "eBox Installer"';

my @tasks = arrayFromFile($TASK_FILE);
my @packages = arrayFromFile($PACKAGE_FILE);

my @selection;
my $option = '';
my $ret = 0;
do {
    unless ($ret == -1) {
        $option = showMenu();
    }
    if ($option eq 'simple') {
        $ret = showChecklist($TASK_TITLE, @tasks);
    } else {
        $ret = showChecklist($PACKAGE_TITLE, @packages);
    }
    if ($ret == 0) {
        @selection = arrayFromFile($SELECTION_FILE);
        unlink ($SELECTION_FILE);
        if (scalar (@selection) == 0) {
            showError('You must select at least one package.');
            $ret = -1;
        }
    }
} while ($ret != 0);

foreach my $package (@selection) {
    print "$package ";
}
print "\n";

sub arrayFromFile # (filename)
{
    my ($filename) = @_;

    my $fh;
    open ($fh, '<', "$INSTALL_FILES_PATH/$filename") or
        open ($fh, '<', $filename) or
            die "Can't read $filename file";
    my @array = <$fh>;
    chomp (@array);
    close ($fh);

    return @array;
}

sub showMenu
{
    my $title = 'Choose package selection method';

    my $size = 2;
    my $height = $size + 7;
    my $width = 60; # FIXME: find proper size instead of random one

    my $command = "whiptail $WHIPTAIL_ARGS --nocancel --title \"$title\" " .
                  "--menu \"$title\" $height $width $size ";

    $command .= "simple \"Select typical sets of packages\" ";
    $command .= "advanced \"Select packages manually\" ";

    my $file = 'selected_option';
    system ("$command 2> $file");
    my @lines = arrayFromFile($file);
    unlink ($file);

    return $lines[0];
}

sub showChecklist # (title, options)
{
    my ($title, @options) = @_;

    my $size = scalar (@options);
    if ($size > 14) {
        $size = 14;
    }
    my $height = $size + 7;
    my $width = 60; # FIXME: find proper size instead of random one

    my $command = "whiptail $WHIPTAIL_ARGS --separate-output " .
                  "--checklist \"$title\" $height $width $size ";

    foreach my $option (@options) {
        $command .= "$option \"FIXME: Description\" 0 ";
    }

    system ("$command 2> $SELECTION_FILE");
}

sub showError # (message)
{
    my ($message) = @_;

    my $title = 'Error';

    my $size = 1;
    my $height = $size + 7;
    my $width = length($message) + 7;

    my $command = "whiptail $WHIPTAIL_ARGS --title \"$title\" " .
                  "--msgbox \"$message\" $height $width";

    system ($command);
}
