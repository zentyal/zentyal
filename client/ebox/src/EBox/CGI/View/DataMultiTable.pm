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

package EBox::CGI::View::DataMultiTable;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
#       The <EBox::CGI::View::DataMultiTable> constructor
#
# Parameters:
#
#       multiTableModel - <EBox::Model::DataMultiTable> the multi table model
#
#
sub new
  {

    my $class = shift;
    my %params = @_;

    my $self = $class->SUPER::new('template' => '/ajax/tableSelector.mas',
				  @_);

    $self->{multiTableModel} = delete $params{multiTableModel};

    bless($self, $class);
    return $self;

  }

sub _process
  {

    my $self = shift;

    my @params;
    push ( @params, $self->{multiTableModel} );

    $self->{'params'} = \@params;

  }

1;
