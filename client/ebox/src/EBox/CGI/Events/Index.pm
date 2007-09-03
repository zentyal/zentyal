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

# Class: EBox::CGI::Events::Index
#
#      The CGI to show the main menu for the events including the
#      enable/disable and event watchers/dispatcher tabs
#

package EBox::CGI::Events::Index;

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
                                    'template' => '/events/index.mas',
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

      return [];

  }

# Method: masonParameters
#
#     The mason parameters to fill the template
#
# Overrides:
#
#     <EBox::CGI::Base::masonParameters>
#
sub masonParameters
  {

      my $gl = EBox::Global->getInstance();
      my $events = $gl->modInstance('events');
      my $eventsModel = $events->configureEventModel();
      my $eventsDispatcherModel = $events->configureDispatcherModel();

      my $modelsRef = [
                       {
                        modelInstance => $eventsModel,
                        directory     => $eventsModel->directory(),
                       },
                       {
                        modelInstance => $eventsDispatcherModel,
                        directory     => $eventsDispatcherModel->directory(),
                       },
                      ];
      return [
              enabled   => $events->service(),
              modelsRef => $modelsRef
             ];

  }

1;
