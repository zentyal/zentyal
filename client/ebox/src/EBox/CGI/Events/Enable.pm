# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::CGI::Events::Enable
#
#      The CGI to enable or disable the event architecture, namely the
#      event daemon. It was redirect to the Index CGI.
#

package EBox::CGI::Events::Enable;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
# Overrides:
#
#       <EBox::CGI::ClientBase::new>
#
sub new
  {

      my $class = shift;
      my $self = $class->SUPER::new('title'    => __('Events'),
                                    @_);
      $self->{domain} = 'ebox-events';
      bless($self, $class);
      return $self;

  }

# Method: requiredParameters
#
#     The required CGI parameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
  {

      return [qw(active change)];

  }

# Method: actuate
#
#     The main method which embebbed the whole CGI logic
#
# Overrides:
#
#     <EBox::CGI::Base::actuate>
#
sub actuate
  {

      my ( $self ) = @_;

      # Redirect to Index CGI
      $self->setChain('Events/Index');

      my $gl = EBox::Global->getInstance();
      my $events = $gl->modInstance('events');

      my $active = $self->param('active');
      if ( $active eq 'yes' ) {
          $events->setService(1);
      } else {
          $events->setService(0);
      }

      # Delete params since it works alright (FIXME FIXME FIXME!: setChain
      # hell)
      $self->cgi()->delete('active');
      $self->cgi()->delete('change');

  }

1;
