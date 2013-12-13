# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenChange::CGI::Migration::Connect;

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;
use EBox::Global;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(title    => __('Mailbox Migration'),
                                  template => 'openchange/migration/connect.mas',
                                  @_);
    bless ($self, $class);
    return $self;
}

# Method: masonParameters
#
#  Return the adequate template parameter for its state.
#
# Returns:
#
#   A reference to a list which contains the names and values of the different
#   mason parameters
#
# Overrides: <EBox::CGI::Base>
#
sub masonParameters
{
    my ($self) = @_;

    if (exists $self->{params}) {
        return $self->{params};
    }

    my $openchangeMod = EBox::Global->modInstance('openchange');
    return ['openchangeMod' => $openchangeMod];
}

1;
