# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Squid::Types::UnlimitedInt;

use base 'EBox::Types::Int';

use EBox::Exceptions::External;
use EBox::Gettext;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/squid/ajax/viewer/unlimitedIntViewer.mas';
    }

    $opts{'type'} = 'unlimited_int';
    $opts{'optional'} = 1;
    $opts{'optionalLabel'} = 0;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Group: Protected methods

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Int::_paramIsSet>
#
sub _paramIsSet
{
    return 1;
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Int::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    unless (defined ($value)) {
        return 1;
    }

    return $self->SUPER::_paramIsValid($params);
}

1;
