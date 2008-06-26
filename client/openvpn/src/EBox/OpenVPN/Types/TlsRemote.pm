# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::OpenVPN::Types::TlsRemote;
use base 'EBox::OpenVPN::Types::Certificate';

#

use strict;
use warnings;

use EBox::Gettext;

# Constructor: new
#

# Returns:
#
#     a <EBox::Types::OpenVPN::TlsRemote> object
#
sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(
                                  defaultValue => 0,
                                  %opts
    );

    bless($self, $class);
    return $self;
}

sub options
{
    my ($self) = @_;

    my @options = @{ $self->SUPER::options() };
    push @options, { value =>  0,printableValue => __('disabled'), };
    return \@options;

}

1;
