# Copyright (C) 2012-2014 Zentyal S.L.
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

package EBox::RemoteServices::QAUpdates;

#   Package to manage the Zentyal QA Updates

use HTML::Mason;
use File::Slurp;
use File::Temp;

use EBox::Config;
use EBox::Exceptions::Command;
use EBox::Module::Base;
use EBox::RemoteServices::Configuration;
use EBox::Sudo;
use Data::UUID;

use TryCatch::Lite;

# Group: Public methods

# Method: set
#
#       Turn the QA Updates ON or OFF depending on the subscription level
#
sub set
{
    my ($global, $subscriptionLevel) = @_;
    # Downgrade, if necessary
    _downgrade($subscriptionLevel);

    _setQAUpdates($global, $subscriptionLevel);
}

# Group: Private methods

sub _setQAUpdates
{
    my ($global, $subscriptionLevel) = @_;

    # Set the QA Updates if the subscription level is greater than basic
    if ($subscriptionLevel < 1) {
        return;
    }

    _setQASources($global);
    _setQAAptPubKey();
    _setQAAptPreferences();
    _setQARepoConf($global);

    my $softwareMod = $global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(1);
            $softwareMod->save();
        }
    } else {
        EBox::info('No software module installed QA updates should be done by hand');
    }
}

# Set the QA source list
sub _setQASources
{
    my ($global) = @_;
    my $archive = _archive();
    my $repositoryHostname = _repositoryHostname($global);

    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $sourcesFile = EBox::Config::stubs . 'core/remoteservices/qa-sources.mas';
    my $comp = $interp->make_component(comp_file => $sourcesFile);

    my $remoteservices = $global->modInstance('remoteservices');
    my $subscriptionInfo = $remoteservices->subscriptionInfo();
    my $uuid = $subscriptionInfo->{server}->{uuid};
    my $user = $subscriptionInfo->{company}->{name} . '-' . $subscriptionInfo->{server}->{name};
    # Password: UUID in hexadecimal format (without '0x')
    my $ug = new Data::UUID;
    my $bin_uuid = $ug->from_string($uuid);
    my $hex_uuid = $ug->to_hexstring($bin_uuid);
    my $pass = substr($hex_uuid, 2);                # Remove the '0x'

    my @tmplParams = ( (repositoryHostname  => $repositoryHostname),
                       (archive             => $archive),
                       (user                => $user),
                       (pass                => $pass));
    # Secret variables for testing
    if ( EBox::Config::configkey('qa_updates_repo_port') ) {
        push(@tmplParams, (port => EBox::Config::configkey('qa_updates_repo_port')));
    }
    if ( EBox::Config::boolean('qa_updates_repo_no_ssl') ) {
        push(@tmplParams, (ssl => (not EBox::Config::boolean('qa_updates_repo_no_ssl'))));
    }

    $interp->exec($comp, @tmplParams);

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("install -m 0644 '$tmpFile' '$destination'");
}

# Get the ubuntu version
sub _ubuntuVersion
{
    my @releaseInfo = File::Slurp::read_file('/etc/lsb-release');
    foreach my $line (@releaseInfo) {
        next unless ($line =~ m/^DISTRIB_CODENAME=/ );
        chomp $line;
        my ($key, $version) = split '=', $line;
        return $version;
    }
}

# Get the Zentyal version to use in the archive
sub _zentyalVersion
{
    return substr(EBox::Config::version(),0,3);
}

# Get the QA archive to look
# qa_updates_archive conf key has higher precedence
sub _archive
{
    if (EBox::Config::configkey('qa_updates_archive')) {
        return EBox::Config::configkey('qa_updates_archive');
    } else {
        my $zentyalVersion = _zentyalVersion();

        return "zentyal-qa-$zentyalVersion";
    }
}

# Get the suite of archives to set preferences
sub _suite
{
    return 'zentyal-qa';
}

# Set the QA apt repository public key
sub _setQAAptPubKey
{
    my $keyFile = EBox::Config::scripts() . '/zentyal-qa.pub';
    EBox::Sudo::root("apt-key add $keyFile");
}

sub _setQAAptPreferences
{
    my $preferences = '/etc/apt/preferences';
    my $fromCCPreferences = $preferences . '.zentyal.fromzc'; # file to store CC preferences

    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $prefsFile = EBox::Config::stubs . 'core/remoteservices/qa-preferences.mas';
    my $comp = $interp->make_component(comp_file  => $prefsFile);
    $interp->exec($comp, ( (archive => _suite()) ));

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);

    EBox::Sudo::root("cp '$tmpFile' '$fromCCPreferences'");

    return unless EBox::Config::boolean('qa_updates_exclusive_source');

    my $preferencesDirFile = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("install -m 0644 '$fromCCPreferences' '$preferencesDirFile'");
}

# Set up the APT conf
#  * No use HTTP proxy for QA repository
#  * No verify server certificate
sub _setQARepoConf
{
    my ($global) = @_;
    my $repoHostname = _repositoryHostname($global);
    EBox::Module::Base::writeConfFileNoCheck(EBox::RemoteServices::Configuration::aptQAConfPath(),
                                             '/core/remoteservices/qa-conf.mas',
                                             [ repoHostname => $repoHostname ],
                                             {
                                                 force => 1,
                                                 mode  => '0644',
                                                 uid   => 0,
                                                 gid   => 0,
                                             }
                                            );
}

# Get the repository hostname
sub _repositoryHostname
{
    my ($global) = @_;
    my $rs = $global->modInstance('remoteservices');
    if ( EBox::Config::configkey('qa_updates_repo') ) {
        return EBox::Config::configkey('qa_updates_repo');
    } else {
        return 'qa.' . $rs->cloudDomain();
    }
}

# Remove QA updates
sub _removeQAUpdates
{
    _removeAptQASources();
    _removeAptPubKey();
    _removeAptQAPreferences();
    _removeAptQAConf();

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(0);
            $softwareMod->save();
        }
    }
}

sub _removeAptQASources
{
    my $path = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptPubKey
{
    my $id = 'ebox-qa';
    try {
        EBox::Sudo::root("apt-key del $id");
    } catch {
        EBox::error("Removal of apt-key $id failed. Check it and if it exists remove it manually");
    }
}

sub _removeAptQAPreferences
{
    my $path = '/etc/apt/preferences.zentyal.fromzc';
    EBox::Sudo::root("rm -f '$path'");
    $path = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptQAConf
{
    my $path = EBox::RemoteServices::Configuration::aptQAConfPath();
    EBox::Sudo::root("rm -f '$path'");
}

# Downgrade current subscription, if necessary
# Things to be done:
#   * Remove QA updates configuration
#   * Uninstall zentyal-cloud-prof and zentyal-security-updates packages
#
sub _downgrade
{
    my ($subscriptionLevel) = @_;
    # If Basic subscription or no subscription at all
    if ($subscriptionLevel <= 0) {
        if ( -f EBox::RemoteServices::Configuration::aptQASourcePath()
            or -f EBox::RemoteServices::Configuration::aptQAPreferencesPath() ) {
            # Requires to downgrade
            _removeQAUpdates();
        }
    }
}

1;
