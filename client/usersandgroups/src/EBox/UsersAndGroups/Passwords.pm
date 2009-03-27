# Copyright (C) 2009 eBox Technologies S.L.
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

    my $passwords = [];

    my $format_string = EBox::Config::configkey('password_formats');
    if (not defined($format_string)) {
        $format_string = allPasswordFormats;
    }
    my @formats = split(',', $format_string);
    for my $format (@formats) {
        my $hasher = passwordHasher($format);
        my $hash = $hasher->($password, $user);
        push(@{$passwords}, 'ebox' . ucfirst($format) . 'Password', $hash);
    }
    return $passwords;
}

1;
