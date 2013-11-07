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

package EBox::OpenChange::CGI::Migration::Progress;

# Class: EBox::OpenChange::CGI::Migration::Progress
#
#   Base CGI to start the migration process
#
use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(title    => __('Mailbox Migration Progress'),
                                  template => 'openchange/migration/progress.mas',
                                  @_);
    bless ($self, $class);
    return $self;
}

# Method: masonParameters
#
#    Return the mason parameters to paint the template
#
# Overrides:
#
#    <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my @params;

    my $oc = EBox::Global->modInstance('openchange');
    my $state = $oc->get_state();
    my $users = $state->{migration_users};

    my $mailboxes = [];
    foreach my $user (@{$users}) {
        push (@{$mailboxes}, {
            name => $user->{name},
            username => $user->{name},
            total => 0,});
    }

    push (@params, totalData => 0); # Data in bytes
    push (@params, mailboxes => $mailboxes);

    return \@params;
}

1;
