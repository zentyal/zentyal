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

package EBox::OpenChange::CGI::Migration::ActivateMailbox;

# Class: EBox::OpenChange::CGI::Migration::ActivateMailbox
#
#    CGI to activate a mailbox after copying its data
#

use base 'EBox::CGI::Base';

use EBox::Gettext;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

sub _process
{
    my ($self) = @_;

    # TODO: Remove copied data and stop migrating this mailbox
    my $username = $self->param('username');

    # Structure expected by Zentyal.OpenChange.discardMailbox function

    $self->{json} = {
        'success'         => __x('{user} mailbox activated', user => $username),
        'printable_value' => __('Migrated'), # To have all i18n in server side
    };

    # Set this on error
    #$self->{json}->{error} = 'error msg';
    # Set this on warning
    # Impossible to discard...
    #$self->{json}->{warning} = 'warning msg';
}

1;
