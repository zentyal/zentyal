# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::UsersAndGroups::ImportFromLdif::Base;

#

use strict;
use warnings;

use Perl6::Junction qw(all);

sub classesToProcess
{
    return [];
}


#XXX this must be called automatically maybe with a parents key i nthe
#specification (this would need a processClass common method to be called
#instead of directly call process[Classname] form the import engine

sub processParents
{
    my ($package, $entry, %params) = @_;
    exists $params{parents} or die "Parent arguments needed";
    $entry   or die "Not entry supplied";

    my @parents = @{ delete $params{parents} };
    @parents or die "Parent list is empty";

    my $allObjectClasses = all($entry->get_value('objectClass'));
    foreach my $parent (@parents) {
	if ($parent ne $allObjectClasses) {
	    my $subName = 'process' . ucfirst $parent;
	    $package->$subName($entry, %params);
	}
    }

}




1;
