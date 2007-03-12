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

package EBox::CGI::TrafficShaping::Controller::RuleMultiTable;

use strict;
use warnings;

use base 'EBox::CGI::Controller::DataMultiTable';

use EBox::Gettext;
use EBox::Global;
use Error qw(:try);

sub new # (cgi=?)
  {

    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);
    return $self;

  }

# This CGI has an only parameter
#         table - id for selecting table
sub _process
  {

    my $self = shift;

    $self->_requireParam('tableSelection');
    my $tableId = $self->param('tableSelection');

    my $global = EBox::Global->getInstance();
    my $ts = $global->modInstance('trafficshaping');

    # Template parameters
    my @tplParams;

    try {
      my $ruleModel = $ts->ruleModel($tableId);

      push ( @tplParams, 'data'      => $ruleModel->rows() );
      push ( @tplParams, 'dataTable' => $ruleModel->tableInfo() );
      push ( @tplParams, 'hasChanged' => $global->unsaved() );

      $self->{params} = \@tplParams;
    }
      catch EBox::Exceptions::External with {

	# If the rule model is empty, return nothing
	$self->setRedirect('/TrafficShaping/Index');

      }

  }

1;
