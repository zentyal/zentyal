#!/usr/bin/perl -w

# Copyright (C) 2008-2012 Zentyal S.L.
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

# This script is intended to perform the password strength check

package EBox::RemoteServices::Audit::Password::Script;

use EBox::RemoteServices::Audit::Password;
use Getopt::Long;
use Pod::Usage;

# Check the passwords
sub _passwordCheck
{
    EBox::RemoteServices::Audit::Password::userCheck();
}

# MAIN

# Get arguments
my ($usage) = (0);
my $correct = GetOptions(
    'usage|help' => \$usage,
   );

if ( $usage or (not $correct)) {
    pod2usage(1);
}

EBox::init();

_passwordCheck();

1;

__END__

=head1 NAME

password-checker.pl - Utility to perform a security audit (password checker) over your Zentyal servers

=head1 SYNOPSIS

password-checker.pl [--usage|help]

 Options:
    --usage|help  Print this help and exit

=cut



