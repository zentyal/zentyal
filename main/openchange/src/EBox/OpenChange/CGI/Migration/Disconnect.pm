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

package EBox::OpenChange::CGI::Migration::Disconnect;

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(title    => __('Mail Box Migration'),
                                  @_);
    $self->{redirect} = 'OpenChange/Migration/Connect';
    bless ($self, $class);
    return $self;
}

# Method: actuate
#
#    Kill the migration process and redirect
#
# Overrides:
#
#    <EBox::CGI::ClientBase>
#
sub actuate
{
    my ($self) = @_;

    # TODO: Kill migration process

    # No parameters to send to the chain
    my $request = $self->request();
    my $parameters = $request->parameters();
    $parameters->clear();
}

1;
