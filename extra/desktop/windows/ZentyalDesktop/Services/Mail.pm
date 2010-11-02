# Copyright (C) 2010 eBox Technologies S.L.
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

package ZentyalDesktop::Services::Mail;

use ZentyalDesktop::Config qw(TEMPLATES_DIR);

sub configure
{
    my ($class, $server, $user, $data) = @_;

    my $mailAccount = $data->{account};

    my $config = ZentyalDesktop::Config->instance();
    my $appData = $config->appData();

    my $exePath = _thunderbirdExePath();
    my $args = '-CreateProfile default';
    my $process;

    Win32::Process::Create($process, $exePath, "$exePath $args", 0, 0, '.');

    my $profilesPath = "$appData/Thundebird/Profiles/";
    $profilesPath =~ s/\\/\//g;
    opendir (my $dir, $profilesPath)
        or return;

    my @files = readdir ($dir);
    my $profileDir;
    foreach my $file (@files) {
        if ($file =~ /default/) {
            $profileDir = $file;
            last;
        }
    }

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
    $template =~ s/MAILACCOUNT/$mailaccount/g;
    $template =~ s/PROTOCOL/$protocol/g;
    $template =~ s/SSL/$ssl/g;

    open (my $confFH, '>', "$profileDir/prefs.js");
    print $confFH $template;
    close ($confFH);
}

sub _thunderbirdExePath
{
    my $version = $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Thunderbird/CurrentVersion"};
    my $path = $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Thunderbird/$version/Main/PathToExe"};

    return $path;
}

1;
