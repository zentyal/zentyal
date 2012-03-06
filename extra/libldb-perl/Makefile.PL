use 5.012004;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'LDB',
    VERSION_FROM      => 'lib/LDB.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/LDB.pm', # retrieve abstract from module
       AUTHOR         => 'Samuel Cabrero <scabrero@zentyal.com>') : ()),
    LIBS              => ['-lldb -L/usr/lib/x86_64-linux-gnu/samba -L/usr/lib/i386-linux-gnu/samba -lldbsamba'], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
