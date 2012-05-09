# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::CGI::DesktopServices::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use Error qw(:try);
use JSON::XS;

use EBox::RemoteServices::Desktop::Subscription;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    $self->{subscription} = new EBox::RemoteServices::Desktop::Subscription();

    return $self;
}

# Method: actuate
#
# Overrides:
#
#    <EBox::CGI::Base::actuate>
#
sub actuate
{
    my ($self) = @_;

    $self->_requireParam('action');
    my $action = $self->param('action');

    if ($action eq 'subscribe') {
        $self->{json} = $self->{subscription}->subscribe();
    } elsif ($action eq 'unsubscribe') {
        $self->{subscription}->unsubscribe();
    } else {
        throw EBox::Exceptions::Internal("Action '$action' not supported");
    }
}

1;
