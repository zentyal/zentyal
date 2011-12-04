#!/usr/bin/perl

# Copyright (C) 2008 Warp Networks S.L.
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

#

use strict;
use warnings;

use Data::Dumper;

use EBox;
use EBox::Global;


my ($module, $model, $method, @params) = @ARGV;

$module or
    die 'not module specified';
$model or
    die 'not model specified';



EBox::init();


my $modInstance = EBox::Global->modInstance($module);
$modInstance or
    die "Cannot get instance of module $module";


my $modelInstance = $modInstance->model($model);
$modelInstance or
    die "Cannot get instance of module $model";


if (not $method) {
    print "Model $model : instantiation sucessful\n";
    exit 0;
}


my $res = $modelInstance->$method(@params);
print Dumper $res;
print "\n";



1;
