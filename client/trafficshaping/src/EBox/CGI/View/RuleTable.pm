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

package EBox::CGI::TrafficShaping::View::RuleTable;

use strict;
use warnings;

use base 'EBox::CGI::View::DataTable';

use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
#           The viewer for the traffic shaping table
#
# Returns:
#
#           The recently created <EBox::TrafficShaping::View::RuleTable>
#
sub new # (cgi=?)
  {
    my $class = shift;

    my $global = EBox::Global->getInstance();
    my $ts = $global->modInstance('trafficshaping');
    $ts->startUp;
    my $self = $class->SUPER::new('title' => __('Traffic Shaping rules'),
				  'tableModel' => $ts->tableModel(),
				  @_);
    $self->{domain} = 'ebox-trafficshaping';
    bless($self, $class);
    return $self;
  }

1;
