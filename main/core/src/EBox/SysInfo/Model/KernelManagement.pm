# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::SysInfo::Model::KernelManagement
#
#   This model is used to manage the system status report feature
#
package EBox::SysInfo::Model::KernelManagement;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#       Create the new KernelManagement model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::SysInfo::Model::KernelManagement> - the recently created model
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (EBox::Types::Boolean>)
#
# The only avaiable action is edit and only makes sense for 'enabled'.
#
sub _table
{
    my @tableDesc = (
        new EBox::Types::Boolean(
            fieldName     => 'enableKM',
            printableName => __('Enable kernel management'),
            editable      => 1,
            unique        => 1,
        ),
    );

    my $dataForm = {
        tableName          => __PACKAGE__->nameFromClass(),
        printableTableName => __('Kernel management'),
        modelDomain        => 'SysInfo',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
    };

    return $dataForm;     
}

# Method: crontabStrings
#
#       Builds the crontab line for full and incremental.
#
# Returns:
#
#       Hash ref:
#
#               once        => scheduling crontab lines for kernel management once a day
#
#       Note that, it only returns the scheduling part '30 1 * * * *' and not
#       the command
#
sub crontabStrings
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        my $once = _crontabString('1');
        my $strings = {
            once => $once,
        };

        return $strings;
    } else {
        return 0;
    }
}

sub isEnabled
{
    my ($self) = @_;
    my $enabled = $self->row()->valueByName('enableKM');
    
    return $enabled;
}

sub _crontabMinute
{
    return 0;
}

sub _crontabString
{
    my ($hour) = @_;

    my $minute  = _crontabMinute();
    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';

    return ["$minute $hour $monthDay $month $weekDay"];
}

1;
