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

use feature qw(switch);

use EBox::Gettext;
use JSON::XS;
use EBox::OpenChange::MigrationRPCClient;
use TryCatch::Lite;
use POSIX;

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

    try {
        my $rpc = new EBox::OpenChange::MigrationRPCClient();
        # Get status
        my $request = { command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_STATUS() };
        my $response = $rpc->send_command($request);
        if ($response->{code} != 0) {
            $self->{json}->{error} = __('Invalid RPC server state');
            return;
        }

        my $state = $response->{state};
        if ($state == 2) {
            # Start export
            my $request = { command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_EXPORT() };
            my $response = $rpc->send_command($request);
            if ($response->{code} != 0) {
                $self->{json}->{error} = __('Invalid RPC server state');
            } else {
            $self->{json} = {
            'totals' => {
                'total_percentage' => 0,
                'n_mailboxes'      => 0,
                'data_migrated'    => 0,
                'time_left'        => 0,
            },
            'users' => [],
            };
            }
        }

        EBox::info("The daemon is in state: " . $response->{state});
        my $donePercentage = 0;
        my $users = $response->{users};
        my $nMailBoxes = scalar @{$users};
        my $totalMigratedBytes = 0;
        my $secondsLeft = 0;
        my $usersData = [];

        if ($state == 3 || $state == 4 || $state == 5 || $state == 6) {
            my $totalBytes = $response->{totalBytes};
            my $totalItems = $response->{totalItems};
            my $exportedItems = $response->{exportedTotalItems};
            my $importedItems = $response->{importedTotalItems};
            if ($totalItems > 0) {
                $donePercentage = floor(($exportedItems + $importedItems) / ($totalItems) * 100);
            }
            my $errorPercentage = 100 - $donePercentage;

            my $totalMigratedBytes = $response->{importedTotalBytes} + $response->{exportedTotalBytes};

            my $secondsLeft = (($totalBytes - $totalMigratedBytes) * 8 ) / (100 * 1024 * 1024);

            foreach my $user (@{$users}) {
#"emails": { "emailBytes": 214564614, "emailItems": 1026, "exportedEmailItems": 0, "exportedEmailBytes": 0, "importedEmailItems": 0, "importedEmailBytes": 0 },
                my $mailBytes = $user->{emails}->{mailBytes};
                my $exportedMailBytes = $user->{emails}->{exportedEmailBytes};
                my $importedMailBytes = $user->{emails}->{importedEmailBytes};
                my $mailPercentage = 0;
                if ($mailBytes > 0) {
                    $mailPercentage = floor(($exportedMailBytes + $importedMailBytes) / ($mailBytes) * 100);
                } else {
                    $mailPercentage = 100;
                }

#"calendars": { "appointmentBytes": 382, "appointmentItems": 1, "exportedAppointmentItems": 0, "exportedAppointmentBytes": 0, "importedAppointmentItems": 0, "importedAppointmentBytes": 0 },
                my $calendarItems = $user->{calendars}->{appointmentItems};
                my $exportedCalendarItems = $user->{calendars}->{exportedAppointmentItems};
                my $importedCalendarItems = $user->{calendars}->{importedAppointmentItems};
                my $calendarPercentage = 0;
                if ($calendarItems > 0) {
                    $calendarPercentage = floor(($exportedCalendarItems + $importedCalendarItems) / ($calendarItems * 2) * 100);
                } else {
                    $calendarPercentage = 100;
                }

#"contacts": { "contactBytes": 123098, "contactItems": 232, "exportedContactItems": 0, "exportedContactBytes": 0, "importedContactItems": 0, "importedContactBytes": 0 },
                my $contactsItems = $user->{contacts}->{contactItems};
                my $importedContactItems = $user->{contacts}->{importedContactItems};
                my $exportedContactItems = $user->{contacts}->{exportedContactItems};
                my $contactsPercentage = 0;
                if ($contactsItems > 0) {
                    $contactsPercentage = floor(($exportedContactItems + $importedContactItems) / ($contactsItems) * 100);
                } else {
                    $contactsPercentage = 100;
                }

                my $errorCount = $totalItems - $exportedItems;
                my $status = {
                    done => $donePercentage,
                    error => $errorPercentage,
                    state => ($state == 6) ? 'migrated' : 'ongoing',
                    printable_value => ($state == 6) ? __('Migrated') : __('on going'),
                };

                my $data = {
                    'username'     => $user->{name},
                    'mail_pct'     => $mailPercentage,
                    'calendar_pct' => $calendarPercentage,
                    'contacts_pct' => $contactsPercentage,
                    'errors'       => $errorCount,
                    'status'       => $status
                };
                push (@{$usersData}, $data);
            }

            if ($state == 4) {
                # Start import
                 my $request = { command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_IMPORT() };
                 my $response = $rpc->send_command($request);
                 if ($response->{code} != 0) {
                     $self->{json}->{error} = __('Invalid RPC server state');
                 }
            }
        }
        # Structure expected by Zentyal.OpenChange.progress function
        $self->{json} = {
            'totals' => {
                'total_percentage' => $donePercentage,
                'n_mailboxes'      => $nMailBoxes,
                'data_migrated'    => 0,
                'time_left'        => $secondsLeft
            },
            'users' => $usersData,
        };

    } catch ($error) {
        # Set this on error
        $self->{json}->{error} = $error;
    }
}

1;
