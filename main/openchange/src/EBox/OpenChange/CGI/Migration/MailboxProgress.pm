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

use EBox::Gettext;
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
        'users' => [
            {
                'username'     => 'jvals',
                'mail_pct'     => 20, # %
                'calendar_pct' => 33.33, # %
                'contacts_pct' => 23.12, # %
                'errors'       => 0,
                'status'       => { done  => 30, # %
                                    error => 0,  # %
                                    state => 'ongoing' },
               },
            {
                'username'     => 'the-offspring',
                'mail_pct'     => 100, # %
                'calendar_pct' => 100, # %
                'contacts_pct' => 100, # %
                'errors'       => 3,
                'status'       => { done  => 95, # %
                                    error => 5,  # %
                                    state => 'migrated',
                                    printable_value => __('Migrated'),
                                },
               },
            {
                'username'     => 'arctic-monkeys',
                'mail_pct'     => 100, # %
                'calendar_pct' => 10, # %
                'contacts_pct' => 34.2, # %
                'errors'       => 21,
                'status'       => { done  => 80, # %
                                    error => 10,  # %
                                    state => 'stopped',
                                },
               },
            {
                'username'     => 'i-wanna-be-yours',
                'mail_pct'     => 10, # %
                'calendar_pct' => 100, # %
                'contacts_pct' => 3.1, # %
                'errors'       => 220,
                'status'       => { done  => 15, # %
                                    error => 30,  # %
                                    state => 'cancelled',
                                    printable_value => __('Cancelled'),
                                },
               },
            {
                'username'     => 'mercromina',
                'status'       => { state => 'waiting',
                                    printable_value => __('Waiting'),
                                },
            },
           ]
    };

    # Set this on error
    #$self->{json}->{error} = 'error msg';
}

1;
