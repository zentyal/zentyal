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

# Class: EBox::Samba::Model::ExportGroups
#
#   Simple model that provides an export button.
#   The actual export with progress bar is handled by the ExportGroups CGI.
#
package EBox::Samba::Model::ExportGroups;

use base 'EBox::Model::DataForm::Action';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );
    return $self;
}

sub _table
{
    my @tableHead = (
        new EBox::Types::Boolean(
            fieldName     => 'exportConfirm',
            printableName => __('Confirm export of domain groups to CSV'),
            hidden        => 1,
            editable      => 1,
            defaultValue  => 1,
        ),
    );

    my $dataTable = {
        'tableName'          => __PACKAGE__->nameFromClass(),
        'printableTableName' => __('Export domain groups'),
        'printableActionName' => __('Export groups to CSV'),
        'automaticRemove'    => 1,
        'defaultActions'     => ['add', 'del', 'editField', 'changeView'],
        'tableDescription'   => \@tableHead,
        'class'              => 'dataTable',
        'modelDomain'        => 'Samba',
    };

    return $dataTable;
}

sub formSubmitted
{
    my ($self, $row) = @_;

    # Redirect to the ExportGroups CGI which uses ProgressClient
    $self->pushRedirection('/Samba/ExportGroups?action=run');
    $self->setMessage('', 'note');
}

sub _setDefaultMessages
{
    my ($self) = @_;

    unless (exists $self->table()->{'messages'}->{'update'}) {
        $self->table()->{'messages'}->{'update'} = __('Groups export started');
    }
}

sub Viewer
{
    return '/ajax/form.mas';
}

sub precondition
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    if ($ed) {
        return 0;
    }

    if (! $dep) {
        return 0;
    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    # Don't show community edition message here; ExportUsers already shows it
    if ($ed) {
        return '';
    }

    if (! $dep) {
        return '';
    }
}

1;