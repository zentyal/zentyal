#/usr/bin/perl
#
# D-BUS client example to request the upgrade process from Exchange to OpenChange
#
# OpenChange Project
#
# Copyright (C) Zentyal SL 2013
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use warnings;
use strict;

use Net::DBus;
use Net::DBus::Reactor;
use Carp qw(cluck carp);
#$SIG{__WARN__} = sub { cluck $_[0] };
#$SIG{__DIE__} = sub { carp $_[0] };


exit main();

sub main {
my $bus = Net::DBus->system();

my $service = $bus->get_service("org.zentyal.openchange.Upgrade");
my $object = $service->get_object(
    "/org/zentyal/openchange/Upgrade",
    "org.zentyal.openchange.Upgrade");

print $object->Run() . "\n";

my $propertySignal = $object->connect_to_signal(
    'PropertyChanged', \&propertyChangedSignalHandler);

print $propertySignal . "\n";
my $reactor = Net::DBus::Reactor->main();
$reactor->run();

return 0;
}

sub propertyChangedSignalHandler {
    my ($property, $value) = @_;
    print "Property $property changed its value to $value\n";
}
