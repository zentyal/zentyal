#!/usr/bin/perl
use threads;
use IO::File;
use DBI;
use EBox::Global;
use Data::Dumper;

my $global = EBox::Global->getInstance;
my $names = $global->modNames;

foreach my $name (@$names) {
	print STDERR "Checking module $name\n";
	my $mod = EBox::Global->modInstance($name);
	my $logs = $mod->logs;
	foreach my $log (@{$logs}) {
		print STDERR "Logger started: " . $log->{'module'} . "." . 
			$log->{'table'} . "\n\\- file: " . $log->{'file'} . "\n";
		threads->new(\&log,$log->{'file'}, $log->{'module'}, $log->{'table'},
			$log->{'fields'}, $log->{'regex'}, $log->{'types'});
	}
}

foreach my $thr (threads->list) {
	if($thr->tid) {
		$thr->join;
	}
}

sub log {
	my ($file, $module, $table, $fields, $regex, $types) = @_;
	my $fh = new IO::File;

	my $nfields = @{$fields};
	$dbh = DBI->connect("DBI:Pg:dbname=log","logger","logger");
	$sth = $dbh->prepare("INSERT INTO $module.$table " .
		"(" . join(',', @{$fields}) . ") " .
		"VALUES (" . "?," x ($nfields-1) . "?" . ")");

	my @types = @{$types};
	while($fh->open("< $file")) {
		my $line;
		while($line = <$fh>) {
			my @data = ($line =~ m/$regex/);
			print STDERR Dumper(@data);
			if($nfields == @data) {
				for(my $i=0; $i!=@data; $i++) {
					my $value = $data[$i];
					if($types[$i] eq 'varchar') {
					} elsif($types[$i] eq 'timestamp') {
					} elsif($types[$i] eq 'inet') {
					} elsif($types[$i] eq 'integer') {
						unless($value =~ /^\d+$/){
							$data[$i] = undef;
						}
					}
				}
				$sth->execute(@data);
			}
			print STDERR $line;
		}
	}
	print STDERR "Unable to open $file\n";
}
