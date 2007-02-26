# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::CGI::TrafficShaping::Controller::RuleTable;

use strict;
use warnings;

use base 'EBox::CGI::Controller::DataTable';

use EBox::Gettext;
use EBox::Global;

sub new # (cgi=?)
  {

    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Traffic Shaping rules'),
				  @_);
    $self->{domain} = 'ebox-trafficshaping';
    bless($self, $class);
    return $self;

  }

# Retrieve as parameters:
# action
# tablename
# directory
# editid
sub _process
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $ts = $global->modInstance('trafficshaping');
    $self->_requireParam('directory');
    my $dir = $self->param('directory');
    # Get the interface from directory
    my ($iface) = split ('/', $dir);
    $self->{tableModel} = $ts->ruleModel($iface);
    $self->SUPER::_process(@_);

  }

1;
