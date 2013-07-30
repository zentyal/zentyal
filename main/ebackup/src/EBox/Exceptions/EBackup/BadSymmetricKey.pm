# Copyright (C) 2011-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Exceptions::EBackup::BadSymmetricKey;

use base 'EBox::Exceptions::External';

use EBox::Gettext;

sub new
{
    my ($class, $text, @params) = @_;
    $text or
        $text = __('Incorrect symmetric key');

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;

    $Log::Log4perl::caller_depth++;
    my $self = $class->SUPER::new($text, @params);
    $Log::Log4perl::caller_depth--;

    bless ($self, $class);
    return $self;
}

1;
