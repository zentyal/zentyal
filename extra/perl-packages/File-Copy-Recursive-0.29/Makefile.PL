use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'File::Copy::Recursive',
    VERSION_FROM      => 'Recursive.pm',
    PREREQ_PM         => { 
        File::Copy => 0,
        File::Spec => 0
    },
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'Recursive.pm',
       AUTHOR         => 'Daniel Muey <http://drmuey.com/cpan_contact.pl>') : ()),
);
