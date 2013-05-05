# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::MigrationTool;

use strict;
use warnings;

use base qw(EBox::GConfModule);

use EBox::Gettext;
use EBox::Global;

sub _create
{
    my $class = shift;
    my $self =$class->SUPER::_create(name => 'migration-tool',
                                     printableName => __('Migration Tool'),
                                     @_);

    bless($self, $class);
    return $self;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $item = new EBox::Menu::Item('name' => 'MigrationTool',
                                    'text' => $self->printableName(),
                                    'url' => 'MigrationTool/Help',
                                    'separator' => 'Core',
                                    'order' => 110);
    $root->add($item);
}

1;
