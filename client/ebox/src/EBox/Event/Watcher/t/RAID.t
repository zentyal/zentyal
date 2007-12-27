# Copyright (C) 2007 Warp Networks S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;
use Test::MockObject;
use Test::Differences;
use Test::Cmd;
use File::Slurp qw(read_file);

use lib '../../../..';
use EBox::Event::Watcher::RAID;
use EBox::Report::RAID;
use EBox::TestStub;

EBox::TestStub::fake();
Test::MockObject->fake_module(
			      'EBox::Report::RAID',
			      _mdstatContents => \&_fakeMdstatContents,
			     );

my @cases;


# RAID 1  resyncing
push @cases,  {
	       mdstatFile => './testdata/raid1-mdstat-resync.txt',

	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active, degraded, resyncing',
		     type   => 'raid1',
		     activeDevices       => 2,
		     activeDevicesNeeded => 2,
		     blocks              => 8289472,


		     operation => 'resync',

		     operationPercentage => '81.9',
		     operationEstimatedTime => '0.9min',
		     operationSpeed         => '26652K/sec',

		    raidDevices => {
			0 => {
			       device => '/dev/sda2',
			       state  => 'up',
			     },
		        1 => {
			       device => '/dev/sdb1',
			       state => 'up',

			     },
		       2 =>  {
			       device => '/dev/sdc1',
			       state => 'spare',
			     },

			
		    },
		     
		  },
	       },

	      }; # close push


# RAID 1 normal state
push @cases,  {
	       mdstatFile => './testdata/raid1-mdstat.txt',

	       expectedRaidInfo => {

	       },

	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active',
		     type   => 'raid1',
		     activeDevices       => 2,
		     activeDevicesNeeded => 2,
		     blocks              => 8289472,

		     operation => 'none',

		    raidDevices => {
			0 => {
			       device => '/dev/sda2',
			       state  => 'up',
			     },
		        1 => {
			       device => '/dev/sdb1',
			       state => 'up',

			     },
		       2 =>  {
			       device => '/dev/sdc1',
			       state => 'spare',
			     },

			
		    },
		     
		  },
	       },


	      }; # close push





# # RAID 1 failure in one device, rebuilding
push @cases,  {
	       mdstatFile => './testdata/raid1-mdstat-failure-rebuild.txt',
	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active, degraded, recovering',
		     type   => 'raid1',
		     activeDevices       => 1,
		     activeDevicesNeeded => 2,
		     blocks              => 8289472,

		     operation => 'recovery',

		     operationPercentage => '0.0',
		     operationEstimatedTime => '1381.5min',
		     operationSpeed         => '0K/sec',

		    raidDevices => {
			1 => {
			       device => '/dev/sdb1',
			       state  => 'up',
			     },
		        3 => {
			       device => '/dev/sdc1',
			       state => 'spare',

			     },
		       2 =>  {
			       device => '/dev/sda2',
			       state => 'failure',
			     },

			
		    },
		     
		  },
	       },


};


# # RAID 1 failure in one device, aafter rebuilding
push @cases,  {
	       mdstatFile => './testdata/raid1-mdstat-failure.txt',
	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active',
		     type   => 'raid1',
		     activeDevices       => 2,
		     activeDevicesNeeded => 2,
		     blocks              => 8289472,

		     operation => 'none',

		    raidDevices => {
			0 => {
			       device => '/dev/sda2',
			       state  => 'up',
			     },
		        1 => {
			       device => '/dev/sdc1',
			       state => 'up',

			     },
		       2 =>  {
			       device => '/dev/sdb1',
			       state => 'failure',
			     },

			
		    },
		     
		  },
	       },


};


#  two raid arrays: raid0 and raid1
push @cases,  {
	       mdstatFile => './testdata/raid1-raid0-mdstat.txt',
	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active',
		     type   => 'raid1',
		     activeDevices       => 2,
		     activeDevicesNeeded => 2,
		     blocks              => 1469824,

		     operation => 'none',

		    raidDevices => {
			0 => {
			       device => '/dev/sda2',
			       state  => 'up',
			     },
		        1 => {
			       device => '/dev/sdb1',
			       state => 'up',

			     },
		       2 =>  {
			       device => '/dev/sdc1',
			       state => 'spare',
			     },

			
		    },
		     
		  },

		 '/dev/md1' => {
				 active => 1,
                                 state  => 'active',
				 type   => 'raid0',

				activeDevices       => 1,
				activeDevicesNeeded => 1,
			 	blocks              => 1566208,
				chunkSize           => '64k',

				operation => 'none',

				raidDevices => {
					      0 => {
						     device => '/dev/sdd1',
						     state  => 'up',
						   },
					 },
			       },
	       },


};


# RAID5
push @cases,  {
	       mdstatFile => './testdata/raid5-mdstat.txt',
	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active',
		     type   => 'raid5',
                     algorithm => 2,

		     activeDevices       => 3,
		     activeDevicesNeeded => 3,
		     blocks              => 1959680,
		     chunkSize           => '64k',

		     operation => 'none',

		    raidDevices => {
			0 => {
			       device => 'scsi/host0/bus0/target0/lun0/part1',
			       state  => 'up',
			     },
		       1 =>  {
			       device => 'scsi/host0/bus0/target1/lun0/part1',
			       state => 'up',
			     },
		        2 => {
			       device => 'scsi/host0/bus0/target2/lun0/part1',
			       state => 'up',

			     },

			
		    },
		     
		  },
	       },


};



# RAID5, mixed ide & scsi
push @cases,  {
	       mdstatFile => './testdata/raid5-ide-scsi-mdstat.txt',
	       expectedRaidInfo => {
		 unusedDevices => [],

		 '/dev/md0' => {
		     active => 1,
                     state  => 'active',
		     type   => 'raid5',
                     algorithm => 2,

		     activeDevices       => 3,
		     activeDevicesNeeded => 3,
		     blocks              => 1895424,
		     chunkSize           => '64k',

		     operation => 'none',

		    raidDevices => {
			0 => {
			       device => '/dev/hda2',
			       state  => 'up',
			     },
		       1 =>  {
			       device => '/dev/hdd1',
			       state => 'up',
			     },
		        2 => {
			       device => '/dev/sda1',
			       state => 'up',
			     },
		        3 => {
			       device => '/dev/hdb1',
			       state => 'spare',
			     },
			
		    },
		     
		  },
	       },


};

my $watcher = new EBox::Event::Watcher::RAID();

my $cmd = new Test::Cmd( prog => '/usr/bin/gconftool',
                         verbose => 1);
$cmd->run( args => '--recursive-unset "/ebox/state/events"');
cmp_ok( $? , '==', 0, 'Deleting previous state');

my @tests = (
             { result => 1, str => 'Added first event'},
             { result => 2, str => 'Operation resync finished and state changed'},
             { result => 4, str => 'Operation recovery after a component fail'},
             { result => 5, str => 'Operation recovery completed'},
             { result => 1, str => 'Added RAID0'},
             { result => 8, str => 'Using RAID5'},
             { result => 7, str => 'Changing devices and partitions'},
            );
for (my $step = 0; $step < $#cases; $step++) {
    setFakeMdInfo( $cases[$step]->{mdstatFile} );
    cmp_ok ( @{$watcher->run()}, '==',
             $tests[$step]->{result}, $tests[$step]->{str});
}

FAKE_SUBS:{
  my $mdstatFile;

  sub setFakeMdInfo
    {
      ($mdstatFile) = @_;
      diag "Using file $mdstatFile as  /proc/mdstat";
    }


  sub _fakeMdstatContents
    {
      my $contents_r = read_file($mdstatFile, array_ref => 1);
      return $contents_r;
    }



}


1;
