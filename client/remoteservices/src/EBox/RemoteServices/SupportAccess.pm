# Copyright (C) 2009 EBox Technologies S.L.
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

package EBox::RemoteServices::SupportAccess;

use strict;
use warnings;

use EBox::Config;
use EBox::Sudo;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Module::Base;



use constant USER_NAME => 'ebox-remote-support';
use constant USER_COMMENT => 'user for eBox remote support';


sub setEnabled
{
    my ($self, $enable) = @_;

    my $user = remoteAccessUser();
    my $keysFile = EBox::Config::share() . 
                   'ebox-remoteservices/' .                  
                       'remote-support.keys';

    if (not $self->userExists($user)) {
        if (not $enable) {
            return;
        } else {
            my $cmd = "useradd $user --create-home " .
                      q{--comment '} . USER_COMMENT . q{'}; 
            EBox::Sudo::root($cmd);
 
        }
    }

    $self->userCheck();

    if ($enable) {
        $self->_createSshFiles($user, $keysFile);      
        $self->_writeScreenConf($user);
    } else {
        my $sshDir   = $self->_sshDir($user);
        EBox::Sudo::root("rm -rf $sshDir");
    }

}

sub remoteAccessUser
{
    return USER_NAME;
}


sub userExists
{
    my ($class, $user) = @_;
    my $exists = getpwnam($user);
    return $exists;
}

sub userCheck
{
    my ($self) = @_;
    my $user = $self->remoteAccessUser();
    if (not $self->userExists($user)) {
        # nothing to check...
        return;
    }

    my ($name,$passwd,$uid,$gid,  $quota,$comment,$gcos,) = getpwnam($user);

    if ($gcos ne USER_COMMENT) {
        throw EBox::Exceptions::External(__x(
'There exists already a user {u} and it does not seem created by eBox. Until this user is renamed or removed it would be impossible to set up remote support access',
                                    u => $user ));
    }
}

sub _createSshFiles
{
    my ($self, $user, $keyFile) = @_;
    my $sshDir = $self->_sshDir($user);
    EBox::Sudo::root("mkdir -p --mode=0700 $sshDir");
    EBox::Sudo::root("cp $keyFile $sshDir/authorized_keys");
    EBox::Sudo::root("chmod 0600 $sshDir/authorized_keys");
    EBox::Sudo::root("chown -R $user.$user $sshDir");
    
}


sub _sshDir
{
    my ($self, $user) = @_;
    my $homedir = $self->_homedir($user);
    my $path = $homedir . '/.ssh';
    return $path;
}


sub _screenRc
{
    my ($self, $user) = @_;
    my $homedir = $self->_homedir($user);
    return "$homedir/.screenrc";

}

sub _homedir
{
    my ($self, $user) = @_;
    my ($name,$passwd,$uid,$gid,
        $quota,$comment,$gcos,$homedir,$shell,$expire) = getpwnam($user);
    return $homedir;
}


sub _writeScreenConf
{
    my ($self, $user) = @_;

    my $conf = 'multiuser on';


    my $eboxUser = EBox::Config::user();
    my @parts = getgrnam('adm');
    my $memberStr = $parts[3];

    my @users = grep { 
        $_ ne $eboxUser
    } split '\s', $memberStr;

    if (not @users) {
        EBox::error("No users for the adm group!, Cannot create screen then");
        return;
    }

    my $userStr = join ',', @users;
    $conf .= "\n";
    $conf .= qq{aclchg $userStr -w "#"\n};
    $conf .= "defwritelock on\n";
    $conf .= q{caption always 'eBox support - %H'};
    $conf .= "\n";

    my $screenRc = $self->_screenRc($user);
    EBox::Module::Base::writeFile(
                                  $screenRc,
                                  $conf,
                                 );
    EBox::Sudo::root("chown $user.$user $screenRc");
    EBox::Sudo::root("chsh -s /usr/bin/screen $user");
}



1;
