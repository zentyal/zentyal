
use ExtUtils::MakeMaker;

WriteMakefile(
		'NAME'          => 'Test::MockTime',
		'VERSION_FROM'  => 'lib/Test/MockTime.pm',
		'PREREQ_PM'     => {
				'Test::More' => 0,
				'Time::Local' => 0,
				'Time::Piece' => '1.08',
					},
);
