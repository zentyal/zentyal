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

package ZentyalDesktop::Mail;

use ZentyalDesktop::Config qw(TEMPLATES_DIR);
use Win32::Registry;
use Win32::TieRegistry(Delimiter => '/', ArrayValues => 0);
use ZentyalDesktop::Log;

my $logger = ZentyalDesktop::Log::logger();

sub configure
{
    my ($class, $server, $user, $data) = @_;
    $logger->debug("Mail configure -> server: $server user: $user account: $data->{account}");

    my $mailAccount = $data->{account};

    my $config = ZentyalDesktop::Config->instance();
    my $appData = $config->appData();

    my $TEMPLATES_DIR = TEMPLATES_DIR;

    my $exePath = _thunderbirdExePath();
    my $args = '-CreateProfile default';
    $logger->debug("execute: $exePath $args");

    my $process;
    Win32::Process::Create($process, $exePath, "$exePath $args", 0, 0, '.');
    $process->Wait('60000');

    my $profilesPath = "$appData/Thunderbird/Profiles/";
    $logger->debug("profiles path: $profilesPath");
    $profilesPath =~ s/\\/\//g;

    my $dir;
    eval{ opendir ($dir, $profilesPath);};
    if ($@) {
        $logger->error("ERROR: $@");
        return;
    };

    my @files = readdir ($dir);
    my $profileDir;
    foreach my $file (@files) {
        if ($file =~ /default/) {
            $profileDir = $file;
            last;
        }
    }
    $logger->debug("profile dir: $profileDir");

    closedir ($dir);

    my $protocol = $config->mailProtocol();
    my $useSSL = $config->mailSSL();

    my $ssl;
    if ($useSSL = 'always') {
        $ssl = '2';
    } elsif ($userSSL = 'never') {
            $ssl = '0';
    } else {
        $ssl = '1';
    }

    open (my $templateFH, '<', "$TEMPLATES_DIR/thunderbird/prefs.js");
    my $template = join ('', <$templateFH>);
    close ($templateFH);

    $template =~ s/USER/$user/g;
    $template =~ s/SERVER/$server/g;
    $template =~ s/MAILACCOUNT/$mailAccount/g;
    $template =~ s/PROTOCOL/$protocol/g;
    $template =~ s/SSL/$ssl/g;

    open (my $confFH, '>', "$profilesPath/$profileDir/prefs.js");
    print $confFH $template;
    close ($confFH);
}

sub _thunderbirdExePath
{
    my $path;
    eval {
        my $lMachine=Win32::TieRegistry->Open('LMachine', {Access=>KEY_READ(),Delimiter=>"/"});
        my $versionKey = $lMachine->Open('SOFTWARE/Mozilla/Mozilla Thunderbird', {Access=>KEY_READ(),Delimiter=>"/"});
        my $version = $versionKey->GetValue('CurrentVersion');
        undef $versionKey;
        my $pathKey = $lMachine->Open("SOFTWARE/Mozilla/Mozilla Thunderbird/$version/Main", {Access=>KEY_READ(),Delimiter=>"/"});
        $path = $pathKey->GetValue('PathToExe');
        undef $pathKey;
        undef $lMachine;
    };
    if ($@) {
        $logger->error("ERROR: $@. Exit");
        return;
    } else {
        $logger->debug("Thunderbird exe path: $path");
    };
    return $path;
}

1;
