# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

use Test::More tests => 20;
use Test::Exception;
use Test::MockObject;
use Test::Differences;
use File::Slurp qw(read_file);
use Data::Dumper;

use lib '../../..';
use EBox::Report::RAID;
use EBox::TestStub;
use Dir::Self;


EBox::TestStub::fake();
Test::MockObject->fake_module('EBox::Report::RAID', _mdstatContents => \&_fakeMdstatContents);

# set a datadir
my $datadir = __DIR__ . '/testdata';

my @cases;

# RAID 1  resyncing
push @cases, {
    mdstatFile => "$datadir/raid1-mdstat-resync.txt",

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
};

# RAID 1 normal state
push @cases, {
    mdstatFile => "$datadir/raid1-mdstat.txt",

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
                2 => {
                    device => '/dev/sdc1',
                    state => 'spare',
                },
            },
        },
    },
};


# RAID 1 with bitmap
push @cases, {
    mdstatFile => "$datadir/raid1-mdstat-w-bitmap.txt",

    expectedRaidInfo => {
        '/dev/md1' => {
            active => 1,
            state  => 'active',
            type   => 'raid1',
            activeDevices       => 2,
            activeDevicesNeeded => 2,
            blocks              => 39060416,

            operation => 'none',

            raidDevices => {
                0 => {
                    device => '/dev/sdb1',
                    state => 'up',

                },
                1 => {
                    device => '/dev/sda1',
                    state  => 'up',
                },

            },
            bitmap => '6/150 pages [24KB], 128KB chunk',
        },

        '/dev/md4' => {
            active => 1,
            state  => 'active',
            type   => 'raid1',
            activeDevices       => 2,
            activeDevicesNeeded => 2,
            blocks              => 9968256,

            operation => 'none',

            raidDevices => {
                0 => {
                    device => '/dev/sda4',
                    state  => 'up',
                },
                1 => {
                    device => '/dev/sdb4',
                    state => 'up',

                },

            },
            bitmap => '0/153 pages [0KB], 32KB chunk',
        },

        '/dev/md3' => {
            active => 1,
            state  => 'active',
            type   => 'raid1',
            activeDevices       => 2,
            activeDevicesNeeded => 2,
            blocks              => 732419328,

            operation => 'none',

            raidDevices => {
                0 => {
                    device => '/dev/sda3',
                    state  => 'up',
                },
                1 => {
                    device => '/dev/sdb3',
                    state => 'up',
                },
            },
            bitmap => '0/175 pages [0KB], 2048KB chunk',
        },

        '/dev/md2' => {
            active => 1,
            state  => 'active',
            type   => 'raid1',
            activeDevices       => 2,
            activeDevicesNeeded => 2,
            blocks              => 195310144,

            operation => 'none',

            raidDevices => {
                0 => {
                    device => '/dev/sda2',
                    state  => 'up',
                },
                1 => {
                    device => '/dev/sdb2',
                    state => 'up',
                },
            },
            bitmap => '0/187 pages [0KB], 512KB chunk',
        },
    }
};



# # RAID 1 failure in one device, rebuilding
push @cases, {
    mdstatFile => "$datadir/raid1-mdstat-failure-rebuild.txt",

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
                    state  => 'failure',
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

# # RAID 1 failure in one device, after rebuilding
push @cases, {
    mdstatFile => "$datadir/raid1-mdstat-failure.txt",

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

# two raid arrays: raid0 and raid1
push @cases, {
    mdstatFile => "$datadir/raid1-raid0-mdstat.txt",

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
push @cases, {
    mdstatFile => "$datadir/raid5-mdstat.txt",

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
push @cases, {
    mdstatFile => "$datadir/raid5-ide-scsi-mdstat.txt",
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

# RAID5, spare device
push @cases, {
    mdstatFile => "$datadir/raid5-spare-mdstat.txt",
    expectedRaidInfo => {
        unusedDevices => [],

        '/dev/md0' => {
            active => 1,
            state  => 'active',
            type   => 'raid5',
            algorithm => 2,

            activeDevices       => 3,
            activeDevicesNeeded => 3,
            blocks              => 1949615104,
            chunkSize           => '512k',

            operation => 'none',

            raidDevices => {
                2 => {
                    device => '/dev/sdc2',
                    state  => 'up',
                },
                1 => {
                    device => '/dev/sdb2',
                    state => 'up',
                },
                3 => {
                    device => '/dev/sdd2',
                    state => 'spare',
                },
                0 => {
                    device => '/dev/sda2',
                    state => 'up',
                },
            },
        },
    },
};

# 4 device raid5 up and running
push @cases, {
    mdstatFile => "$datadir/raid5-4up.txt",

    expectedRaidInfo => {
        unusedDevices => [],

        '/dev/md127' => {
            active => 1,
            state  => 'active',
            type   => 'raid5',
            algorithm => 2,

            activeDevices       => 4,
            activeDevicesNeeded => 4,
            blocks              => 4395408384,
            chunkSize           => '512k',

            operation => 'none',

            raidDevices => {
                2 => {
                    device => '/dev/sdc1',
                    state  => 'up',
                },
                1 => {
                    device => '/dev/sdb1',
                    state => 'up',
                },
                4 => {
                    device => '/dev/sdd1',
                    state => 'up',
                },
                0 => {
                    device => '/dev/sda1',
                    state => 'up',
                },
            },
        },
    },
};

foreach my $case (@cases) {
    setFakeMdInfo($case->{mdstatFile});

    my $expectedMdDevices = $case->{expectedMdDevices};
    my $expectedInfo      = $case->{expectedRaidInfo};

    my $actualMdDevices;
    my $actualInfo;
    lives_ok {
        $actualInfo      = EBox::Report::RAID::info();
    } 'getting RAID and MD devices information for file ' . $case->{mdstatFile};

    if ($case->{dump}) {
        diag "about to dump\n";
        diag Dumper $actualInfo;
    }

    SKIP: {
        skip  'Error getting RAID information' unless defined $actualInfo;
        is_deeply $actualInfo, $expectedInfo, 'checking RAID info contents';
    }
}

FAKE_SUBS: {
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
