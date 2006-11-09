# $Id: Makefile.PL,v 1.1.1.1 2004/11/28 23:38:28 simonflack Exp $
use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'Test::MockModule',
    'VERSION_FROM'	=> 'lib/Test/MockModule.pm',
    'PREREQ_PM'		=> { 'Test::More'   => 0.45,
                         'Scalar::Util' => 0, },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/Test/MockModule.pm',
       AUTHOR     => 'Simon Flack') : ()),
);
