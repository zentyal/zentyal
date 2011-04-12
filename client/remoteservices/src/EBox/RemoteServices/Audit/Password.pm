# Copyright (C) 2008-2011 eBox Technologies S.L.
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

package EBox::RemoteServices::Audit::Password;

use EBox;
use EBox::Config;
use EBox::Exceptions::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Configuration;
use EBox::Sudo;
use Error qw(:try);
use File::Basename;
use File::Temp;
use Perl6::Junction qw(any);
use User::pwent;

use constant {
    JOHN                 => 'nice john',
    LDAP_USERS_PASS_LIST => EBox::Config::tmp() . 'lupl.jtrf',
    SYSTEM_USERS_PASS_LIST => EBox::Config::tmp() . 'supl.jtrf',
    LDAP_SINGLE_USERS_PASS_LIST => EBox::Config::tmp() . 'lsupl.jtrf',
    SYSTEM_SINGLE_USERS_PASS_LIST => EBox::Config::tmp() . 'ssupl.jtrf',
    DOING_CRACKING_FILE    => EBox::Config::tmp() . 'jtr.lock',
    JOHN_WRAPPER         => EBox::Config::share() . 'ebox-remoteservices/john-wrapper',
    HOME_DIR             => EBox::RemoteServices::Configuration::JohnHomeDirPath(),
};

# Procedure: reportUserCheck
#
#     Report the results for a user check, if available.
#
# Returns:
#
# Returns:
#
#     array ref - containing the following keys:
#
#        username - user name whose password is weak
#        level    - the level of the password weakness
#        printableLevel - the printable level of the password weakness
#        from     - users' origin (system)
#
#     undef - if the report is cannot be done
#
sub reportUserCheck
{
    my @users = ();

    # While doing the cracking, we cannot report a thing
    if ( -e DOING_CRACKING_FILE ) {
        return undef;
    }

    my @fileSets = (_systemUserFiles(), _ldapUserFiles());
    foreach my $fileSet (@fileSets) {
        next unless (defined($fileSet));
        try {
            my $fileUsers = _reportResults($fileSet->{single});
            foreach my $user (@{$fileUsers}) {
                push(@users, { username => $user,
                               level    => 'weak',
                               from     => $fileSet->{from}});
            }
            $fileUsers = _reportResults($fileSet->{incremental});
            foreach my $user (@{$fileUsers}) {
                unless ( $user eq any(map {$_->{username}} @users) ) {
                    push(@users, { username => $user,
                                   level    => 'average',
                                   from     => $fileSet->{from}});
                }
            }
        } catch EBox::Exceptions::Command with {
            ;
        };
    }

    return \@users;
}

# Procedure: userCheck
#
#     Check the password strength from users in Zentyal. Those users may
#     system or LDAP users. We use "john the ripper" to do so.
#
#     If any user has an easy-to-crack password, then an alert is sent
#     to our Events subsystem
#
# Returns:
#
#     array ref - containing the following keys:
#
#        username - user name whose password is weak
#        level    - the level of the password weakness
#        printableLevel - the printable level of the password weakness
#        from     - users' origin (system)
#
sub userCheck
{

    unless ( _subscribed() ) {
        return [];
    }

    # Starting the crack
    open(my $fh, '>', DOING_CRACKING_FILE);
    close($fh);
    my $users = [];
    try {
        $users = _check(_systemUserFiles('recreate'), _ldapUserFiles('recreate'));
    } finally {
        unlink(DOING_CRACKING_FILE);
    };

    return $users;
}



# Function: nUsers
#
#      Return the number of users in the system (*NIX and LDAP users)
#
sub nUsers
{

    # System users
    my @users = @{EBox::Sudo::root(EBox::Config::share() . 'ebox-remoteservices/valid-users.pl')};

    # LDAP users
    my $gl = EBox::Global->getInstance(1);
    if ( $gl->modExists('users') ) {
        my $usersMod = $gl->modInstance('users');
        if ( $usersMod->isEnabled() and ($usersMod->mode() eq 'master') ) {
            push(@users, @{$usersMod->uidList()});
        }
    }

    return (scalar(@users));
}

# Function: additionalInfo
#
#     Given the username, get the additional info to show in the
#     report
#
# Parameters:
#
#     username - String the user's name
#
# Returns:
#
#     hash ref - containing the following keys:
#
#        fullname - the full name
#        email    - the email address
#
#     These fields are only available sometimes. full name from system
#     users is guessed using the gecos information
#
sub additionalInfo
{
    my ($username) = @_;

    my $entry;
    if (getpwnam($username)) {
        # System user
        my $userInfo = getpwnam($username);
        my ($fullName) = $userInfo->gecos() =~ m/([^,]+)/g;
        $entry = { username => $username,
                   fullname => $fullName,
                   email    => '' };
    } else {
        # Check against our LDAP
        my $gl = EBox::Global->getInstance(1);
        if ( $gl->modExists('users') ) {
            my $usersMod = $gl->modInstance('users');
            if ( $usersMod->isEnabled() and ($usersMod->mode() eq 'master') ) {
                my $userInfo = $usersMod->userInfo($username);
                my $email = defined($userInfo->{mail}) ? $userInfo->{mail} : '';
                $entry = { username => $username,
                           fullname => $userInfo->{fullname},
                           email    => $email };
            }
        }
    }

    return $entry;

}

# Group: Private procedures


# Return the files where to crack from system files
#
sub _systemUserFiles
{
    my ($recreate) = @_;

    if ( $recreate ) {
        foreach my $fileName ( (SYSTEM_SINGLE_USERS_PASS_LIST, SYSTEM_USERS_PASS_LIST) ) {
            # Unshadow file
            # Destination file has eBox owner with r/w only for the owner
            EBox::Sudo::root("unshadow /etc/passwd /etc/shadow > $fileName");
            chmod(0600, $fileName);
        }
    }
    return {
        single      => SYSTEM_SINGLE_USERS_PASS_LIST,
        incremental => SYSTEM_USERS_PASS_LIST,
        from        => __('system'),
    };

}

# Return the files where to crack from LDAP user files
sub _ldapUserFiles
{

    my ($recreate) = @_;

    my $files = undef;
    my $gl = EBox::Global->getInstance(1);
    if ( $gl->modExists('users') ) {
        my $usersMod = $gl->modInstance('users');
        if ( $usersMod->isEnabled() and ($usersMod->mode() eq 'master') ) {
            if ( $recreate ) {
                my $usersIds = $usersMod->uidList();
                my $passListFile = LDAP_USERS_PASS_LIST;
                my $singlePassListFile = LDAP_SINGLE_USERS_PASS_LIST;
                open(my $fh, '>', $passListFile);
                open(my $fh2, '>', $singlePassListFile);
                foreach my $userId (@{$usersIds}) {
                    my $user = $usersMod->userInfo($userId);
                    print $fh $user->{username} . ':' . $user->{extra_passwords}->{lm} . "\n";
                    print $fh2 $user->{username} . ':' . $user->{extra_passwords}->{lm} . "\n";
                }
                close($fh);
                close($fh2);
                chmod(0600, $passListFile, $singlePassListFile);
            }
            $files = {
                single      => LDAP_SINGLE_USERS_PASS_LIST,
                incremental => LDAP_USERS_PASS_LIST,
                from        => 'LDAP'
               };
        }
    }
    return $files;

}

# Receive the password files
#
# Returns:
#
#     array ref - containing the following keys:
#
#        username - user name whose password is weak
#        level    - the level of the password weakness
#        printableLevel - the printable level of the password weakness
#        from     - users' origin (system)
#
sub _check
{
    my @fileSets = @_;

    my $fileSet = {};
    my @singleSet = map { $_->{single} } @fileSets;
    $fileSet->{single} = \@singleSet;
    my @incrementalSet = map { $_->{incremental} } @fileSets;
    $fileSet->{incremental} = \@incrementalSet;

    my @allUsers;
    foreach my $set (qw(single incremental)) {
        my $mode = '';
        my $printableLevel = __('average');
        my $level = 'strong';
        if ($set eq 'single') {
            $mode = '--single';
            $printableLevel = __('weak');
            $level = 'weak';
        }
        # Must run john twice since we crack different hashes (LM and
        # crypt) LM cracks are case-insensitive but faster than NTLM
        # ones, if we would want the case passwords then we have to
        # change to use the NTLM passwords with patches applied
        foreach my $fileName (@{$fileSet->{$set}}) {
            my ($baseName) = File::Basename::fileparse($fileName, '.jtrf');
            my $sessionOpt = '--session=' . HOME_DIR . $baseName;
            my $shellOpt = '--shells=-' . _shells();
            my $output  = EBox::Sudo::command(
                JOHN_WRAPPER . " $sessionOpt $mode $fileName"
               );
        }
        foreach my $fileName (@{$fileSet->{$set}}) {
            my $users = _reportResults($fileName);
            my $from;
            foreach my $subFileSet (@fileSets) {
                if ( defined($fileName) and $subFileSet->{$set} eq $fileName ) {
                    $from = $subFileSet->{from};
                    last;
                }
            }
            foreach my $user (@{$users}) {
                unless ( $user eq any(map { $_->{username} } @allUsers) ) {
                    push(@allUsers, { username       => $user,
                                      printableLevel => $printableLevel,
                                      level          => $level,
                                      from           => $from});
                }
            }
        }
        _sendEvent(users => \@allUsers, level => $level, printableLevel => $printableLevel);
    }
}

# Disabled shells
sub _shells
{
    return '/bin/false';
}

# Check subscription
sub _subscribed
{
    my $rs = EBox::Global->modInstance('remoteservices');
    return ( $rs->eBoxSubscribed() );
}

# Parse john output
# Return the new guesses and the users whose password is weak
sub _parseOutput
{
    my ($output, $passFile) = @_;

    my $singleLine = join("\n", @{$output});
    my $nGuesses = 0;
    if ( $singleLine =~ m/No password hashes loaded/g ) {
        # No new cracked passwords
    } else {
        ($nGuesses) = $singleLine =~ m/guesses:\s*([0-9]+)\s/;
    }

    my $users = _reportResults($passFile);

    return { newGuesses => $nGuesses,
             users      => $users };
}

# Report the results for a pass file
sub _reportResults
{
    my ($passFile) = @_;

    return [] unless (defined($passFile));

    return [] unless (-r $passFile);

    $output = EBox::Sudo::command(JOHN . " --show $passFile");
    my @users = ();
    foreach my $line (@{$output}) {
        my ($user) = $line =~ m/^([^:]*):/;
        if ( defined($user) ) {
            push(@users, $user);
        }
    }
    return \@users;

}

# Send event
sub _sendEvent
{
    my (%info) = @_;

    my $gl = EBox::Global->getInstance(1);
    if ( $gl->modExists('events') ) {
        try {
            $evtsMod = $gl->modInstance('events');

            # Only send users whose password level is equal to the
            # level to send the event
            my @users = grep { $_->{level} eq $info{level} } @{$info{users}};

            my $message = __x('No {level} passwords were found in users',
                              level => $info{printableLevel});
            my $level = 'info';
            if ( @users > 0 ) {
                $message = '';
                $message .= __x('The following users have {level} passwords: {users}.',
                                level => $info{printableLevel},
                                users => join(', ', map { $_->{username} } @users));
                $level = 'warn';
            }

            $evtsMod->sendEvent(message    => $message,
                                source     => 'password checker',
                                level      => $level,
                                dispatchTo => [ 'ControlCenter' ],
                               );

        } catch EBox::Exceptions::External with {
            EBox::error('Cannot send alert regarding to weak password checker');
        };
    }
}

1;
