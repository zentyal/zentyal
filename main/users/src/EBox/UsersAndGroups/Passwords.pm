# Copyright (C) 2009-2012 eBox Technologies S.L.
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

package EBox::UsersAndGroups::Passwords;

use strict;
use warnings;

use EBox::UsersAndGroups;

sub allPasswordFormats
{
    return 'sha1,md5,lm,nt,digest,realm';
}

sub allPasswordFieldNames
{
    my @formats = split(',', allPasswordFormats());
    my @names = map { 'ebox' . ucfirst($_) . 'Password' } @formats;
    return \@names;
}

sub additionalPasswords
{
    my ($user, $password) = @_;

    my $passwords = {};

    my $format_string = EBox::Config::configkey('password_formats');
    if (not defined($format_string)) {
        $format_string = allPasswordFormats;
    }
    my @formats = split(',', $format_string);
    for my $format (@formats) {
        my $hasher = passwordHasher($format);
        my $hash = $hasher->($password, $user);
        $passwords->{'ebox' . ucfirst($format) . 'Password'} = $hash;
    }
    return $passwords;
}

sub defaultPasswordHash
{
    my ($password) = @_;

    my $format = EBox::Config::configkey('default_password_format');
    if (not defined($format)) {
        $format = 'sha1';
    }
    my $hasher = passwordHasher($format);
    my $hash = $hasher->($password);
    return $hash;
}

sub passwordHasher
{
    my ($format) = @_;

    my $hashers = {
        'sha1' => \&shaHasher,
        'md5' => \&md5Hasher,
        'lm' => \&lmHasher,
        'nt' => \&ntHasher,
        'digest' => \&digestHasher,
        'realm' => \&realmHasher,
    };
    return $hashers->{$format};
}

sub shaHasher
{
    my ($password) = @_;
    return '{SHA}' . Digest::SHA::sha1_base64($password) . '=';
}

sub md5Hasher
{
    my ($password) = @_;
    return '{MD5}' . Digest::MD5::md5_base64($password) . '==';
}


sub lmHasher
{
    my ($password) = @_;
    return Crypt::SmbHash::lmhash($password);
}

sub ntHasher
{
    my ($password) = @_;
    return Crypt::SmbHash::nthash($password);
}

sub digestHasher
{
    my ($password, $user) = @_;
    my $realm = getRealm();
    my $digest = "$user:$realm:$password";
    return '{MD5}' . Digest::MD5::md5_base64($digest) . '==';
}

sub realmHasher
{
    my ($password, $user) = @_;
    my $realm = getRealm();
    my $digest = "$user:$realm:$password";
    return '{MD5}' . Digest::MD5::md5_hex($digest);
}

sub getRealm
{
# FIXME get the LDAP dc as realm when merged iclerencia/ldap-jaunty-ng
    return 'ebox';
}



1;
