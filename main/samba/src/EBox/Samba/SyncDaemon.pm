#!/usr/bin/perl
#
# Copyright (C) 2014 Zentyal S.L.
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

package EBox::Samba::SyncDaemon;

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::Ldap;
use EBox::Samba::User;
use EBox::Samba::Group;
use Perl6::Junction qw(any);
use TryCatch;
use String::ShellQuote;

use constant DEBUG => 0;

sub new
{
    my ($class) = @_;

    my $samba = EBox::Global->getInstance(1)->modInstance('samba');
    my $ldap = $samba->ldap();
    my $rootDse = $ldap->rootDse();
    my $defaultNC = $rootDse->get_value('defaultNamingContext');

    my $self = {
        samba => $samba,
        ldap => $ldap,
        defaultNC => $defaultNC,
    };

    bless ($self, $class);

    return $self;
}

# Method: containers
#
#   Retrieve the containers where users and groups without uidNumber or
#   gidNumber will be search
#
sub containers
{
	my ($self, $ldap, $dn) = @_;

	my $containers = [];
	my $params = {
		base => $dn,
		scope => 'one',
		filter => '(|(objectClass=container)(objectClass=organizationalUnit)(objectClass=msExchSystemObjectsContainer))',
		attrs => ['*'],
	};
	my @entries = @{$ldap->pagedSearch($params)};
	foreach my $entry (@entries) {
		my $containerDN = $entry->dn();
		my $containerCN = $entry->get_value('cn');
		next if $containerCN eq any EBox::Ldap::QUERY_IGNORE_CONTAINERS();
		push (@{$containers}, $containerDN);
	}
	return $containers;
}

# Method: checkUsers
#
#   Set the uidNumber and gidNumber on users
#
sub checkUsers
{
    my ($self, $ldap, $containers) = @_;

    my $samba = $self->{samba};

    # Only set global roaming profiles and drive letter options
    # if we are not replicating to another Windows Server to avoid
    # overwritting already existing per-user settings. Also skip if
    # unmanaged_home_directory config key is defined
    my $unmanagedHomes = (EBox::Config::boolean('unmanaged_home_directory') or ($samba->dcMode() eq 'adc'));

    my $netbiosName = $samba->netbiosName();
    my $realmName = $samba->kerberosRealm();
    my $drive = $samba->drive();
    my $drivePath = "\\\\$netbiosName.$realmName";
    my $profilesEnabled = $samba->roamingProfiles();
    my $profilesPath = $samba->_roamingProfilesPath();

    my $primaryGidNumber = EBox::Samba::User->_domainUsersGidNumber();
    my $userFilter = "(&(&(objectclass=user)(!(objectclass=computer)))(!(isDeleted=*))(!(showInAdvancedViewOnly=*))(!(isCriticalSystemObject=*)))";
    foreach my $containerDN (@{$containers}) {
        my $params = {
            base   => $containerDN,
            scope  => 'sub',
            filter => $userFilter,
            attrs  => ['*'],
        };
        my @entries = @{$ldap->pagedSearch($params)};
        foreach my $entry (@entries) {
            my $user = new EBox::Samba::User(entry => $entry);
            my $dn = $user->dn();
            my $modified = 0;

            EBox::debug("Checking user '$dn' attributes to update...");
            try {
                unless (defined $user->get('uidNumber')) {
                    my $uidNumber = EBox::Samba::User->_newUserUidNumber(0);
                    EBox::Samba::User->_checkUid($uidNumber, 0);
                    $user->set('uidNumber', $uidNumber, 1);
                    EBox::info("Set user '$dn' uidNumber=$uidNumber");
                    $modified = 1;
                }

                unless (defined $user->get('gidNumber')) {
                    $user->set('gidNumber', $primaryGidNumber, 1);
                    EBox::info("Set user '$dn' gidNumber=$primaryGidNumber");
                    $modified = 1;
                }

                unless ($unmanagedHomes) {
                    # Set roaming profiles if needed
                    if ($user->get('profilePath') xor $profilesEnabled) {
                        my $path = $profilesEnabled ? $profilesPath : '';
                        $user->setRoamingProfile($profilesEnabled, $path, 1);
                        EBox::info("Set user '$dn' profilePath='$path'");
                        $modified = 1;
                    }
                    my $currentDrive = $user->get('homeDrive');
                    unless (defined ($currentDrive) and ($currentDrive eq $drive)) {
                        # Mount user home on network drive
                        $user->setHomeDrive($drive, $drivePath, 1);
                        EBox::info("Set user '$dn' homeDrive='$drive' homeDirectory='$drivePath'");
                        $modified = 1;
                    }
                }

                $user->save() if $modified;
            } catch ($error) {
                EBox::error("Error updating attributes on user '$dn': $error");
            }
        }
    }
}

# Method: checkGroups
#
#   Set the gidNumber on groups
#
sub checkGroups
{
    my ($self, $ldap, $containers) = @_;

    my $groupFilter = "(&(objectclass=group)(!(isDeleted=*))(!(showInAdvancedViewOnly=*))(!(isCriticalSystemObject=*)))";
    foreach my $containerDN (@{$containers}) {
        my $params = {
            base   => $containerDN,
            scope  => 'sub',
            filter => $groupFilter,
            attrs  => ['*'],
        };
        my @entries = @{$ldap->pagedSearch($params)};
        foreach my $entry (@entries) {
            my $group = new EBox::Samba::Group(entry => $entry);
            next unless $group->isSecurityGroup();

            my $dn = $group->dn();
            EBox::debug("Checking group '$dn' gidNumber attribute");

            unless (defined $group->get('gidNumber')) {
                try {
                    my ($rid) = $group->sid() =~ m/-(\d+)$/;
                    my $gidNumber = $group->unixId($rid);
                    $group->set('gidNumber', $gidNumber);
                    EBox::info("Set group '$dn' gidNumber '$gidNumber'");
                } catch ($error) {
                    EBox::error("Error setting gidNumber on group '$dn': $error");
                }
            }
        }
    }
}

# Method: syncUsersGroups
#
#   Retrieve containers and check users and groups inside them
#
sub syncUsersGroups
{
    my ($self, $debug) = @_;

    my $defaultNC = $self->{defaultNC};
    unless (defined $defaultNC and length $defaultNC) {
        EBox::error("default naming context not defined");
        return;
    }

    my $ldap = $self->{ldap};
    unless (defined $ldap) {
        EBox::error("ldap not connected");
        return;
    }

    my $containers = $self->containers($ldap, $defaultNC);
    $self->checkGroups($ldap, $containers);
    $self->checkUsers($ldap, $containers);
}

# Method: setACLs
#
#   Set ACLs for shares with pending changes
#
sub setACLs
{
    my ($self) = @_;

    my $samba = $self->{samba};
    my $domainSid = $samba->ldap()->domainSID();
    my $domainAdminsSid = $domainSid . '-512';
    my $domainUsersSid  = $domainSid . '-513';
    my $sambaShares = $samba->model('SambaShares');

    for my $id (@{$sambaShares->ids()}) {
        my $row = $sambaShares->row($id);
        my $enabled     = $row->valueByName('enabled');
        my $shareName   = $row->valueByName('share');
        my $pathType    = $row->elementByName('path');
        my $guestAccess = $row->valueByName('guest');

        unless ($enabled) {
            next;
        }

        my $path = undef;
        if ($pathType->selectedType() eq 'zentyal') {
            $path = $samba->SHARES_DIR() . '/' . $pathType->value();
        } elsif ($pathType->selectedType() eq 'system') {
            $path = $pathType->value();
        } else {
            EBox::error("Unknown share type on share '$shareName'");
        }
        unless (defined $path) {
            next;
        }

        my $syncShareFile = EBox::Config::conf() . "samba/sync_shares/$shareName";
        my $syncShareFileExists = (-f $syncShareFile);

        if (EBox::Sudo::fileTest('-d', $path)) {
            next if EBox::Config::boolean('unmanaged_acls');
            next unless $syncShareFileExists; # share permissions didn't change, nothing needs to be done for this share.
        }

        EBox::info("Starting to apply recursive ACLs to share '$shareName'...");

        my @cmds = ();
        push (@cmds, "mkdir -p '$path'");
        push (@cmds, "setfacl -b '$path'"); # Clear POSIX ACLs
        if ($guestAccess) {
            push (@cmds, "chmod 0777 '$path'");
            push (@cmds, "chown nobody:'domain users' '$path'");
        } else {
            push (@cmds, "chmod 0770 '$path'");
            push (@cmds, "chown administrator:adm '$path'");
        }
        EBox::Sudo::root(@cmds);

        # Posix ACL
        my @posixACL;
        push (@posixACL, 'u:administrator:rwx');
        push (@posixACL, 'g:adm:rwx');
        push (@posixACL, 'g:"domain admins":rwx');

        for my $subId (@{$row->subModel('access')->ids()}) {
            my $subRow = $row->subModel('access')->row($subId);
            my $permissions = $subRow->elementByName('permissions');

            my $userType = $subRow->elementByName('user_group');
            my $perm;
            if ($userType->selectedType() eq 'group') {
                $perm = 'g:';
            } elsif ($userType->selectedType() eq 'user') {
                $perm = 'u:';
            }
            my $account = $userType->value();
            my $qobject = shell_quote($account);
            $perm .= $qobject . ':';

            if ($permissions->value() eq 'readOnly') {
                $perm .= 'rx';
            } elsif ($permissions->value() eq 'readWrite') {
                $perm .= 'rwx';
            } elsif ($permissions->value() eq 'administrator') {
                $perm .= 'rwx';
            } else {
                my $type = $permissions->value();
                EBox::error("Unknown share permission type '$type'");
                next;
            }
            push (@posixACL, $perm);
        }

        if (@posixACL) {
            try {
                EBox::Sudo::root('setfacl -R -m d:' . join(',d:', @posixACL) ." '$path'");
                EBox::Sudo::root('setfacl -R -m ' . join(',', @posixACL) . " '$path'");
            } catch {
                my $error = shift;
                EBox::error("Couldn't enable POSIX ACLs for $path: $error")
            }
        }
        EBox::info("Recursive set of ACLs to share '$shareName' finished.");

        unlink ($syncShareFile) if $syncShareFileExists;
    }
}

# Method: run
#
#   Run the daemon. It never dies.
#
sub run
{
    my ($self, $interval, $random) = @_;

    EBox::info("Samba sync daemon started");

    my $syncUsers = (not EBox::Config::boolean('disabled_uid_sync'));

    while (1) {
        $self->setACLs();

        my $randomSleep = (DEBUG ? (3) : ($interval + int (rand ($random))));
        EBox::debug("Sleeping for $randomSleep seconds");
        sleep ($randomSleep);

        $self->syncUsersGroups(DEBUG) if ($syncUsers);
    }

    EBox::info("Samba sync daemon stopped");
}

if ($0 eq __FILE__) {
    EBox::init();

    # Run each 30 sec + random between (0,10) seconds
    my $loop = new EBox::Samba::SyncDaemon();
    $loop->run(30, 10);
}

1;
