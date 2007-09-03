# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::View::DataTable;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

sub new # (cgi=?)
{
	my $class = shift;
	my %params = @_;
	my $tableModel = delete $params{'tableModel'};
	my $self = $class->SUPER::new('template' => $tableModel->Viewer(),
                                      @_);
	$self->{'tableModel'} = $tableModel;
	bless($self, $class);
	return $self;
}


sub _process
{
	my $self = shift;

	my $global = EBox::Global->getInstance();

	my $model = $self->{'tableModel'};
	my $directory = $self->param('directory');
	if ($directory) {
		$model->setDirectory($directory);
	}
	my $rows = $model->rows(undef, 0);

	my $tpages = $model->pages(undef);
	my @params;
	push(@params, 'data' => $rows);
	push(@params, 'dataTable' => $model->table());
        push(@params, 'model'      => $model);
	push(@params, 'hasChanged' => $global->unsaved());
	push(@params, 'tpages' => $tpages);
	push(@params, 'page' => 0);

	$self->{'params'} = \@params;
}


1;
