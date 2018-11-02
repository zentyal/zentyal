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

use strict;
use warnings;

package EBox::EBackup::Password;

use EBox::Config;
use EBox::Module::Base;
use File::Slurp;

use constant PASSWD_FILE =>  EBox::Config::conf() . 'ebox-ebackup.password';
use constant DUPLICITY_SYMMETRIC_PASSWORD =>  EBox::Config::conf() . '/ebox-ebackup-symmetric.password';
use constant DUPLICITY_GPG_PASSPHRASE =>  EBox::Config::conf() . '/ebox-ebackup-symmetric.gpgpass';

sub setPasswdFile
{
    my ($pass, $alternative) = @_;
    my $file = _passwdFile($alternative);
    EBox::Module::Base::writeFile(
            $file,
            $pass, { uid => 'ebox', gid => 'ebox', mode => '0600'}
    );
}

sub passwd
{
    my ($alternative) = @_;
    my $file = _passwdFile($alternative);
    if (-e $file) {
        return File::Slurp::read_file($file);
    }

    return '';
}

sub _passwdFile
{
    my ($alternative) = @_;
    if ($alternative) {
        return PASSWD_FILE . '.alt';
    }
    return PASSWD_FILE;
}

sub setSymmetricPassword
{
    my ($symPass, $alternative) = @_;
    my $file = _symmetricPasswordFile($alternative);

    EBox::Module::Base::writeFile(
            $file,
            $symPass, { uid => 'ebox', gid => 'ebox', mode => '0600'}
    );
}

sub symmetricPassword
{
    my ($alternative) = @_;
    my $file = _symmetricPasswordFile($alternative);

    if (-e $file) {
        return File::Slurp::read_file($file);
    }

    return '';
}

sub _symmetricPasswordFile
{
    my ($alternative) = @_;
    my $file = DUPLICITY_SYMMETRIC_PASSWORD;
    if ($alternative) {
        $file .= '.alt';
    }

    return $file;
}

sub setGpgPassphrase
{
    my ($symPass, $alternative) = @_;
    my $file = _gpgPassphraseFile($alternative);

    EBox::Module::Base::writeFile(
            $file,
            $symPass, { uid => 'ebox', gid => 'ebox', mode => '0600'}
    );
}

sub gpgPassphrase
{
    my ($alternative) = @_;
    my $file = _gpgPassphraseFile($alternative);

    if (-e $file) {
        return File::Slurp::read_file($file);
    }

    return '';
}

sub _gpgPassphraseFile
{
    my ($alternative) = @_;
    my $file = DUPLICITY_GPG_PASSPHRASE;
    if ($alternative) {
        $file .= '.alt';
    }

    return $file;
}

1;
