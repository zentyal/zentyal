# Copyright (C) 2009-2010 eBox Technologies S.L.
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

# Class: EBox::EGroupware::Model::DefaultApplications
#
#   TODO: Document class
#

package EBox::EGroupware::Model::DefaultApplications;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);

use strict;
use warnings;

use base 'EBox::EGroupware::Model::Applications';

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub _table
{
    my ($self) = @_;

    my $table = $self->SUPER::_table();

    $table->{'tableName'} = 'DefaultApplications';
    $table->{'printableTableName'} = __('Default Applications');
    $table->{'help'} = __('These are the default application permissions that are given to the new created users or existing ones before enabling eGroupware module.');

    return $table;
}

# Method: headTitle
#
#   Override <EBox::Model::DataTable::headTitle>
sub headTitle
{
    return undef;
}


1;
