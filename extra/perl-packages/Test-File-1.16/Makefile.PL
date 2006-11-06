# $Id: Makefile.PL,v 1.6 2005/12/31 21:33:58 comdog Exp $
use ExtUtils::MakeMaker;

eval "use Test::Manifest 1.14";

WriteMakefile
	(
	'NAME'           => 'Test::File',
	'ABSTRACT'       => 'Check file attributes',
	'VERSION_FROM'   => 'lib/File.pm',

	'PREREQ_PM' => {
		'Test::More'            => '0',
		'Test::Builder::Tester' => '0',
		'Test::Builder'         => '0.32',
		},

	'PM'        => {
		'lib/File.pm'     => '$(INST_LIBDIR)/File.pm',
		},

	'MAN3PODS'     => {
		'lib/File.pm' => '$(INST_MAN3DIR)/Test::File.3',
		},

	clean  => { FILES    => q|Test-File-* test_files| },
	);

