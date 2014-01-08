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

package EBox::OpenChange::CGI::Migration::MailboxDetails;

# Class: EBox::OpenChange::CGI::Migration::MailboxDetails
#
#    Return in a HTML the migration details for a mailbox.
#
#    For the moment, no timer is yet done to refresh the data.
#

use base 'EBox::CGI::ClientRawBase';

use EBox;
use EBox::Global;
use EBox::Gettext;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
        template => '/openchange/migration/mailbox_details.mas',
        @_);
    bless ($self, $class);
    return $self;
}

# Group: Public methods

# Method: requiredParameters
#
#    Return the required parameters to fulfill the request
#
# Overrides:
#
#    <EBox::CGI::Base::masonParameters>
#
sub requiredParameters
{
    return [ 'username' ];
}

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
    # If something goes wrong put this in mason
    # push(@params, error => 'foo');
    push(@params, mailbox =>
        {
            username => $self->param('username'),
            total    => {
                done  => 20,
                error => 10,
                state => 'ongoing', #state => 'cancelled', # states: likewise MailboxProgress
                #printable_value => __('Cancelled')
               },
            mail     => {
                total      => 1200,
                migrated   => 600,
                percentage => 600 / 1200 * 100, # %
                errors     => 12,
               },
            calendar => {
                total      => 120,
                migrated   => 60,
                percentage => 60 / 120 * 100, # %
                errors     => 1,
               },
            contacts => {
                total      => 23,
                migrated   => 20,
                percentage => 20 / 23 * 100, # %
                errors     => 0,
               },
        });
    return \@params;

}

1;
