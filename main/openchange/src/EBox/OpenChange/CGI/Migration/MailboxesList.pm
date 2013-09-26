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

package EBox::OpenChange::CGI::Migration::MailboxesList;

# Class: EBox::OpenChange::CGI::Migration::MailboxesList
#
#    Return in a JSON the mailboxes list to migrate from the origin server
#

use base 'EBox::CGI::ClientRawBase';

use EBox;
use EBox::Global;
use EBox::Gettext;

use Error qw(:try);

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
        template => '/openchange/migration/mailboxes_table.mas',
        @_);
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

# Method: masonParameters
#
#    Get the mailbox list from the origin server
#
# Overrides:
#
#    <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    # Mocked up data
    my @params = ();
    push(@params, mailboxes => [
        {
                name     => 'Gutierres Vals, Javier',
                username => 'jvals',
               },
            {
                name     => 'The Offspring',
                username => 'the-offspring',
                status   => undef,
                },
            {
                name     => 'Conspiracy of One',
                username => 'conspiracy',
                status   => 'migrated',
                date     => '19-05-2013', # Use the locale way of showing dates?
                },
            {
                name     => 'Mercromina',
                username => 'mercromina',
                status   => 'cancelled',
                date     => '18-05-2013', # Use the locale way of showing dates?
                },
            {
                name     => 'Les femmes',
                username => 'yelle',
                status   => 'conflict',
                date     => '17-05-2013', # Use the locale way of showing dates?
               },
       ]
        );
    return \@params;

    # If something goes wrong
    #$self->{json}->{error} = 'Error msg';
}

1;
