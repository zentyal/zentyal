use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Authen::Krb5::Easy',
    'VERSION_FROM'	=> 'Easy.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    'LIBS'      => ['-L/usr/lib/x86_64-linux-gnu/ -L/usr/lib/i386-linux-gnu/ -lkrb5'],
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '-I/usr/include/'
);
