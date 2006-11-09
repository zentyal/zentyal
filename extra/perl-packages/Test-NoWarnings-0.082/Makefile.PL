# $Header: $

use strict;

use ExtUtils::MakeMaker;

my $module = "Test::NoWarnings";
my $file_base = $module;
$file_base =~ s/::/\//g;
$file_base = "./lib/$file_base";
my $pm_file = "$file_base.pm";
my $pod_file = "$file_base.pod";

my $doc_file = -e $pod_file ? $pod_file : $pm_file;

(my $dir = $module) =~ s/::/-/g;

WriteMakefile(
	AUTHOR => 'Fergal Daly <fergal@esatclear.ie>',
	NAME => $module,
	VERSION_FROM => $pm_file,
	INSTALLDIRS => 'perl',
	PREREQ_PM => {
		'Test::Tester' => 0.103
	},
	dist => {
		PREOP=> "rm -f README; pod2text -80 < $doc_file > README; cp -f README $dir-\$(VERSION); "
	}
);
