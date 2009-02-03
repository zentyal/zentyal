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

# Class: EBox::CGI::Controller::Composite
#
#      This CGI is the composite controller. That is, it determines
#      what to do after a call to get an action performed.
#
#      It inherits from <EBox::CGI::ClientRawBase>, so the returning
#      HTML just includes what Viewer method returns
#

package EBox::CGI::Controller::Composite;

use base 'EBox::CGI::ClientRawBase';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;

# Constructor: new
#
#       The CGI constructor.
#
# Parameters:
#
#       <EBox::CGI::ClientRawBase::new> the parent parameters
#
#       composite - <EBox::Model::Composite> the composite model to
#       take the action and show it
#
#       action  - String the action to be performed
#
#       - Named parameters
#
# Returns:
#
#       <EBox::CGI::Controller::Composite> - the recently created CGI
#
sub new
  {

      my ($class, %params) = @_;

      my $composite = delete $params{composite};
      my $self = $class->SUPER::new('template' => $composite->Viewer(),
                                    @_);
      $self->{composite} = $composite;
      $self->{action}    = delete $params{action};

      bless( $self, $class);

      return $self;

  }



sub _process
{
    my ($self) = @_;

    my $composite = $self->{composite};

    my $directory = $self->param('directory');
    
    if (defined $directory) {
        $composite->setDirectory($directory);
    }
    else {
        $composite->setDirectory('');
    }

    $self->{params} = $self->masonParameters();
}


# Method: masonParameters
#
#      Overrides <EBox::CGI::ClientBase::masonParameters>
#
sub masonParameters
  {

      my ($self) = @_;

      if ( $self->{action} eq 'changeView' ) {
          my $global = EBox::Global->getInstance();

          return [
                  model  => $self->{composite},
                  hasChanged => $global->unsaved(),
                 ];
      } else {
          return [];
      }

  }

1;
