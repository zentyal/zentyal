package DiskUsageProviderTest;

use strict;
use warnings;

use  lib '../../..';

use base 'EBox::Report::DiskUsageProvider';

use Test::More tests => 2;
use Test::Exception;
use Test::MockObject;
use Test::Differences;


Test::MockObject->fake_module(
			      'EBox::FileSystem',
			       dirDiskUsage => sub { return 1 },
			       dirFileSystem => \&_fakeDirFileSystem,
			     );

my @mockedFacilities = (
			c0 => [],
			c1 => [ 'testdata/dira1'],
			c2 => ['testdata/dirb1', 'testdata/dirb2'],
			c3 => ['testdata/dira2', 'testdata/dirb3' ],
		       );


_fakeFaciltiesForDiskUsage(@mockedFacilities);




my $diskUsageResults;
lives_ok {
  $diskUsageResults = __PACKAGE__->diskUsage(blockSize => 1024);
} 'invoking diskUsage';



my $expectedResults = {
		       '/dev/hda0' => {
				     c1 => 1,
				     c3 => 1,
				    },
		       '/dev/hdb0' => {
				      c2 => 2,
				      c3 => 1,
				     },
		     };
eq_or_diff $diskUsageResults, $expectedResults, 'checking result of disk usage method';


{
  my %_facilities;

  sub _facilitiesForDiskUsage
    {
      return \%_facilities;
    }


  sub _fakeFaciltiesForDiskUsage
    {
      %_facilities = @_;
    }



}


sub _fakeDirFileSystem
  {
    my ($dir) = @_;

    if ($dir =~ m{^testdata/dir(\w)\d$}) {
      my $deviceLetter = $1;
      return '/dev/hd' . $deviceLetter . '0';
    } else {
      die "bad name for fake dir: $dir. Must be in the form testdata/dir\\w\\l";
    }
  }

1;
