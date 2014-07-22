# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Zarafa::Model::VMailDomains;

use base 'EBox::Model::DataTable';

use EBox::Config;
use EBox::Gettext;
use EBox::Types::DomainName;

sub vdomains
{
    my ($self) = @_;

    my @vdomains;

    foreach my $domain (@{$self->enabledRows()}) {
        my $row = $self->row($domain);
        my $vdomain = $row->valueByName('vdomain');
        push (@vdomains, $vdomain);
    }

    return \@vdomains;
}

# Method: precondition
#
#   Check if there is at least one vdomain.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $mail = EBox::Global->getInstance()->modInstance('mail');
    my $model = $mail->model('VDomains');
    my $numDomains = scalar (@{$model->ids()});

    return $numDomains > 0;
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail.
#
sub preconditionFailMsg
{
    my ($self) = @_;

    my $mail = EBox::Global->getInstance()->modInstance('mail');
    my $model = $mail->model('VDomains');
    my $numDomains = scalar (@{$model->ids()});

    unless ($numDomains > 0) {
        return __x(
'To configure Zarafa you must have at least one virtual mail domain. You can define one at {ohref}Virtual Domains{chref}.',
ohref => q{<a href='/Mail/View/VDomains/'>},
chref => q{</a>},
        );
    }
}

# Method: notifyForeignModelAction
#
#      Called whenever an action is performed on VDomain model
#      to check if our configured vdomain is going to disappear
#
# Overrides:
#
#      <EBox::Model::DataTable::notifyForeignModelAction>
#
sub notifyForeignModelAction
{
    my ($self, $modelName, $action, $row) = @_;
    if ($modelName ne 'mail/VDomains') {
        return;
    }

    if ($action eq 'del') {
        my $vdomain = $row->valueByName('vdomain');
        my $myRow = $self->findRow(vdomain => $vdomain);
        $myRow or
            return;
        my $selected = $myRow->valueByName('vdomain');
        if ($vdomain eq $selected) {
            $myRow->elementByName('vdomain')->setValue('_none_');
            $myRow->store();
            return __('The deleted virtual domain was selected for ' .
                      'Zarafa. Maybe you want to select another one now.');
        }
    }
    return '';
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $mail = $self->global()->modInstance('mail');
    my $mailModel = $mail->model('VDomains');
    my $mailRows = $mailModel->ids();

    my %mailVDomains = map { $mailModel->row($_)->valueByName('vdomain') => $_ } @{$mailRows};
    my %currentVDomains = map { $self->row($_)->valueByName('vdomain') => $_ } @{$currentRows};

    my $modified = 0;

    my @vdomainsToAdd = grep { not exists $currentVDomains{$_} } keys %mailVDomains;
    foreach my $vdomain (@vdomainsToAdd) {
        $self->add(vdomain => $vdomain);
        # TODO Try to add the domain ou here if doesn't exist
        $modified = 1;
    }

    my @vdomainsToDelete = grep { not exists $mailVDomains{$_} } keys %currentVDomains;
    foreach my $vdomain (@vdomainsToDelete) {
        $self->removeRow($currentVDomains{$vdomain});
        # TODO Try to remove the domain here if empty, otherwise try to show a message
        $modified = 1;
    }

    return $modified;
}

sub _table
{
    # TODO if hosted_zarafa and multi_ou are disabled, only allow to select one and advise to enable
    # experimental hosted_zarafa and multi_ou
    # TODO show a warning is multi_ou is disabled but hosted_zarafa is enabled
    my @tableHead =
    (
        new EBox::Types::DomainName(
            'fieldName' => 'vdomain',
            'printableName' => __('Virtual domain'),
            'editable' => 0,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'VMailDomains',
        'printableTableName' => __('List of Domains'),
        'modelDomain' => 'Zarafa',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('Select the virtual mail domain to be used for Zarafa.'),
        'automaticRemove'  => 1,
        'printableRowName' => __('virtual domain'),
        'sortedBy' => 'vdomain',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
    };

    return $dataTable;
}

1;
