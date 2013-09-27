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
    push(@params, totalData => 342342234); # Data in bytes
    push(@params, mailboxes => [
        {
            name     => 'Gutierres Vals, Javier',
            username => 'jvals',
            total    => 23232321, # Data in bytes
           },
        {
            name     => 'The Offspring',
            username => 'the-offspring',
            total    => 2327882321, # Data in bytes
        },
        {
            name     => 'Arctic Monkeys',
            username => 'arctic-monkeys',
            total    => 234332121, # Data in bytes
        },
        {
            name     => 'I wanna be yours',
            username => 'i-wanna-be-yours',
            total    => 2343621, # Data in bytes
        },
        {
            name     => 'Mercromina',
            username => 'mercromina',
            total    => 232365121, # Data in bytes
        },
       ]);
    return \@params;
}

1;
