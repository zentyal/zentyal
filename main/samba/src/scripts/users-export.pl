#!/usr/bin/perl
use strict;

use EBox;
use EBox::Samba::User;
use EBox::Samba::Group;

use TryCatch;
use Cwd 'abs_path';

my @lines;

sub getUsers 
{
    EBox::init();
    my $samba = EBox::Global->modInstance('samba');

    foreach my $u ( @{ $samba->users() } ) {
        if ( $u->isInternal() ne 0 ) {
            push @lines,
                $u->get('samAccountName') . ';'
		      . $u->parent()->dn() . ';'
              . $u->get('givenName') . ';'
              . $u->initials() . ';'
              . $u->get('sn') . ';'
              . $u->displayName() . ';'
              . $u->description() . ';'
              . '"' . $u->mail() . '"' . ';'
	      			. 'password' . ';'
	      			. $u->isSystem() . ';' 
	      			. $u->uidNumber() . ';'
              . getUserGroups($u) . ";\n";
	        print $u->get('samAccountName') . " done...\n";
        }
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
    open( my $fh, '>', $p )
      or die "Could not create file " . $p . "\n";
    print $fh getUsers();
    close $fh;
    print "Users have been exported on file " . $p . "\n";
    return 1;
}

sub getParms 
{
    my (@args) = @_;
    if ( scalar @args < 1 or scalar @args > 1 ) {
        print "Usage: ./user-exporter <dest-file> \n";
    }
    else {
        writeCSV( $args[0] );
    }
}

EBox::Sudo::root('/usr/bin/touch /var/lib/zentyal/tmp/.users_exporter-running');
getParms(@ARGV);
EBox::Sudo::root('/bin/rm /var/lib/zentyal/tmp/.users_exporter-running');

