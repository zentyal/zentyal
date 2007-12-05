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

# Class: EBox::Events::Model::Watcher::LogFiltering
#
# This class is used to set those filters that you may want to be
# informed. This model is used as template given a set of filters (all
# String-based) and events (a selection) using tableInfo information
# (Check <EBox::LogObserver::tableInfo> for details)
#
# The model composition based on tableInfo information is the
# following: 
#
#     - filter1..n - Text
#     - event      - Selection between the given selections from tableInfo
#

# FIXME ALL code 
package EBox::Events::Model::Watcher::LogFiltering;

1;
