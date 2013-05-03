#!perl
#
# Copyright (C) 2010-2013 Zentyal S.L.
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

use warnings;
use strict;

use ZentyalDesktop::Config;
use ZentyalDesktop::SoftwareConfigurator;
use ZentyalDesktop::Util;
use ZentyalDesktop::Log;

use Win32::Registry;
use Win32::TieRegistry(Delimiter => '/', ArrayValues => 0);

my $appData = $ENV{APPDATA};

ZentyalDesktop::Log->init($appData . '\ZentyalDesktop.log');

my $logger = ZentyalDesktop::Log::logger();
$logger->debug("Begin zentyal-setup-user");

# Exit if configured mark is set
my $configured = $Registry->{'CUser/Software/Zentyal/Zentyal Desktop/Configured'};
if ($configured) {
    $logger->debug('Configured mark is set. Exit');
    exit 0;
};
$logger->debug('Configured mark is not set');


my $config = ZentyalDesktop::Config->instance();
$logger->debug("Application data directory: $appData");
$config->setAppData($appData);

my $server;
eval{
    my $lMachine=Win32::TieRegistry->Open('LMachine', {Access => KEY_READ(), Delimiter => '/'});
    my $serverKey = $lMachine->Open('SOFTWARE/Zentyal/Zentyal Desktop', {Access=>KEY_READ(),Delimiter=>"/"});
    $server = $serverKey->GetValue('SERVER');
    undef $serverKey;
    undef $lMachine;
};
if ($@) {
    $logger->error("ERROR: $^E. Exit");
    exit 1;
} else {
    $logger->debug("Server: $server");
};

my $user = $ENV{USERNAME};
$logger->debug("User: $user");

ZentyalDesktop::SoftwareConfigurator->configure($server, $user);

# Set configured mark
eval{
    my $pathKey = $Registry->{'CUser/Software/'};
    my $newKey = $pathKey->CreateKey('Zentyal/Zentyal Desktop');
    $newKey->{'Configured'} = 1;
    undef $newKey;
};
if ($@) {
    $logger->error("ERROR: $^E. Configured mark is not set");
    exit 1;
} else {
    $logger->debug("Configured mark is set");
};

$logger->debug("End zentyal-setup-user");
exit 0;
