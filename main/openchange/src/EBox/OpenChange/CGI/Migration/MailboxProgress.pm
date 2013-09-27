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

package EBox::OpenChange::CGI::Migration::MailboxProgress;

# Class: EBox::OpenChange::CGI::Migration::MailboxProgress
#
#    CGI to check the current progress of the mailbox migration
#

use base 'EBox::CGI::Base';

use JSON::XS;

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

    # Structure expected by Zentyal.OpenChange.progress function

    $self->{json} = {
        'totals' => {
            'total_percentage' => 23, # %
            'n_mailboxes'      => 1,
            'data_migrated'    => 232321, # in bytes
            'time_left'        => 3700, # in seconds
           },
    };

    # Set this on error
    #$self->{json}->{error} = 'error msg';
}

1;
