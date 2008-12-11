#!/usr/bin/perl -w

# Copyright (C) 2008 eBox Technologies S.L.
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

# A module to test Base measure module

use Clone;
use EBox::Monitor;
use EBox::Gettext;
use File::Temp;
use File::Basename;
use Test::Deep;
use Test::More tests => 34;
use Test::Exception;

BEGIN {
    diag ( 'Starting EBox::Monitor::Measure::Base test' );
    use_ok( 'EBox::Monitor::Measure::Base' )
      or die;
    use_ok( 'EBox::Monitor::Measure::Load' )
      or die;
}

my $tempFile = File::Temp->new( SUFFIX => '.rrd');
my $greatDescription = {
   realms => [ '/tmp' ],
   rrds   => [ File::Basename::basename($tempFile->filename()) ]
  };

my $oldBaseDirFunc = \&EBox::Monitor::RRDBaseDirPath;
*EBox::Monitor::RRDBaseDirPath = sub { return ''; };

throws_ok {
    EBox::Monitor::Measure::Base->new();
} 'EBox::Exceptions::MissingArgument', 'Cannot create an empty base measure';

*EBox::Monitor::Measure::Base::_description = sub {
    return $greatDescription;
};

my $measure;
lives_ok {
    $measure = EBox::Monitor::Measure::Base->new();
} 'Creating a base measure';

# Checking default values
cmp_ok( $measure->{name}, 'eq', ref($measure));
cmp_ok( $measure->{help}, 'eq', '');
cmp_ok( $measure->{printableName}, 'eq', '');
is_deeply( $measure->{datasets}, ['value']);
is_deeply( $measure->{printableLabels}, [ __('value') ]);
cmp_ok( $measure->{type}, 'eq', 'int');

# Starting great stuff
throws_ok {
    $measure->_setDescription( { realms => ['/tmp'],
                                 rrds => [ 'falacia' ]
                                }
                              );
} 'EBox::Exceptions::Internal', 'Setting a non-existant RRD';

# Help and printable name
$greatDescription->{help} = 'foo';
$greatDescription->{printableName} = 'bar';
lives_ok {
    $measure->_setDescription($greatDescription);
} 'Setting a great description';

cmp_ok( $measure->{help}, 'eq', 'foo');
cmp_ok( $measure->{printableName}, 'eq', 'bar');

# Data set and rrds bad types
foreach my $attr (qw(datasets realms printableLabels)) {
    my $badDescription = Clone::clone($greatDescription);
    $badDescription->{$attr} = 'foo';
    throws_ok {
        $measure->_setDescription($badDescription);
    } 'EBox::Exceptions::InvalidType', 'Setting wrong type';
}

my $badDescription = Clone::clone($greatDescription);
$badDescription->{printableLabels} = [ 'foo', 'bar' ];
throws_ok {
    $measure->_setDescription($badDescription);
} 'EBox::Exceptions::Internal', 'Wrong number of printable labels';

# Type
foreach my $type (qw(int percentage grade byte)) {
    $greatDescription->{type} = $type;
    lives_ok {
        $measure->_setDescription($greatDescription);
    } 'Setting true data';
    cmp_ok( $measure->{type}, 'eq', $type);
}

$badDescription = Clone::clone($greatDescription);
$badDescription->{type} = 'foo';
throws_ok {
    $measure->_setDescription($badDescription);
} 'EBox::Exceptions::InvalidData', 'Setting wrong data type';

# Load testing

*EBox::Monitor::RRDBaseDirPath = $oldBaseDirFunc;

my $load;
lives_ok {
    $load = EBox::Monitor::Measure::Load->new();
} 'Creating Load measure';

isa_ok( $load, 'EBox::Monitor::Measure::Load');

my $returnVal;
lives_ok {
  $returnVal = $load->fetchData();
} 'Fetching data';

cmp_deeply($returnVal,
           {
             id   => str($load->realms()->[0]),
             type => any(@{$load->Types()}),
             series => array_each({ label => any(@{$load->{printableLabels}}),
                                    data  => array_each(ignore())}),
            },
           'The fetched data is in correct format');

throws_ok {
    $load->fetchData(realm => 'foobar');
} 'EBox::Exceptions::InvalidData',
  'Trying to fetch data from an unexistant realm';

throws_ok {
    $load->fetchData(start => 'foobar');
} 'EBox::Exceptions::Command',
  'Trying to fetch data with a bad start point';

throws_ok {
    $load->fetchData(end => 'foobar');
} 'EBox::Exceptions::Command',
  'Trying to fetch data with a bad end point';

1;
