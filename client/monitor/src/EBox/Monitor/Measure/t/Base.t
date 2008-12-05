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
use File::Temp;
use Test::More tests => 25;
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
    rrds => [ $tempFile->filename() ]
   };

*EBox::Monitor::RRDBaseDirPath = sub { return '/tmp'; };

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
is_deeply( $measure->{dataset}, ['value']);
cmp_ok( $measure->{type}, 'eq', 'int');

# Starting great stuff
throws_ok {
    $measure->_setDescription( { rrds => [ '/tmp/falacia' ] });
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
foreach my $attr (qw(dataset rrds)) {
    my $badDescription = Clone::clone($greatDescription);
    $badDescription->{$attr} = 'foo';
    throws_ok {
        $measure->_setDescription($badDescription);
    } 'EBox::Exceptions::InvalidType', 'Setting wrong type';
}

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
isa_ok( EBox::Monitor::Measure::Load->new(),
        'EBox::Monitor::Measure::Load');

1;
