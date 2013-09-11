# Copyright (C) 2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Logs::Composite::SummarizedReport;

# Class: EBox::Logs::Composite::SummarizedReport
#
#     Base class for all common logic between composites that show
#     summarised data
#

use base 'EBox::Model::Composite';

use EBox::Gettext;

# Method: HTMLTitle
#
#     Override to set breadcrumbs to Logs
#
# Overrides:
#
#     <EBox::Model::Composite::HTMLTitle>
#
sub HTMLTitle
{
    my ($self) = @_;

    return [
        {
            title => __('Query Logs'),
            link  => '/Maintenance/Logs'
           },
        {
            title => __('Summarized Report'),
            link  => "",
        }
       ];
}

1;
