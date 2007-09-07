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

# Class: EBox::Model::ModelProvider
#
#   Interface meant to be used for classes providing models

package EBox::Model::ModelProvider;

use strict;
use warnings;

use EBox::Gettext;

sub new 
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: models 
# 
#   This method must be overriden in case of your module provides any model
#
# Returns:
#
#	array ref - containing instances of the models
sub models 
{
    return [];
}

1;
