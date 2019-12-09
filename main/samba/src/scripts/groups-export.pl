#!/usr/bin/perl
use strict;

use EBox;
use EBox::Global;
use Cwd 'abs_path';

my @getGroups;
my $checkOptions;
my $getPath;
my $writeCSV;
my @lines;
my $gid;

sub getGroups 
{
    EBox::init();
    my $samba = EBox::Global->modInstance('samba');

    foreach my $g ( @{ $samba->groups() } ) {
        if ( !$g->isInternal() and $g->name ne 'Domain Admins' ) {
            $gid = !$g->isSecurityGroup() ? undef : $g->gidNumber();
            push @lines,
                $g->name() . ';'
              . $g->parent()->dn() . ';'
	      	  . $g->description() . ';'
              . $g->mail() . ';'
              . $g->isSecurityGroup() . ';'
              . $g->isSystem() . ';'
              . $gid . ";\n";
        }
    }

    return @lines;
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
    open( my $fh, '>', $p )
      or die "Could not create file " . $p . "\n";
    print $fh getGroups();
    close $fh;
    print "Groups have been exported on file " . $p . "\n";
    return 1;
}

sub getParms 
{
    my (@args) = @_;
    if ( scalar @args < 1 or scalar @args > 1 ) {
        print "Usage: ./group-exporter <dest-file> \n";
    }
    else {
        writeCSV( $args[0] );
    }
}
EBox::Sudo::root('/usr/bin/touch /var/lib/zentyal/tmp/.groups_exporter-running');
getParms(@ARGV);
EBox::Sudo::root('/bin/rm /var/lib/zentyal/tmp/.groups_exporter-running');

