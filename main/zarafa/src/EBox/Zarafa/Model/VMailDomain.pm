# Copyright (C) 2010-2011 Zentyal S.L.
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

# Class: EBox::Zarafa::Model::VMailDomain
#
#   TODO: Document class
#

package EBox::Zarafa::Model::VMailDomain;

use EBox::Config;
use EBox::Gettext;
use EBox::Types::Select;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub vdomains
{
    my $mail = EBox::Global->getInstance()->modInstance('mail');
    my $model = $mail->model('VDomains');

    my @vdomains;

    push (@vdomains, { value => '_none_', printableValue => __('No domain selected') });

    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $vdomain = $row->valueByName('vdomain');

        push (@vdomains, { value => $vdomain, printableValue => $vdomain });
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

    if ($action eq 'del') {
        my $vdomain = $row->valueByName('vdomain');
        my $myRow = $self->row();
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

# Method: formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    $mail->setAsChanged();
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Select(
            'fieldName' => 'vdomain',
            'printableName' => __('Virtual domain'),
            'disableCache' => 1,
            'populate' => \&vdomains,
            'editable' => 1,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'VMailDomain',
        'printableTableName' => __('Virtual mail domain'),
        'modelDomain' => 'Zarafa',
        'defaultActions' => [ 'editField', 'changeView' ],
        'notifyActions' => [ 'VDomains' ],
        'tableDescription' => \@tableHead,
        'help' => __('Select the virtual mail domain to be used for Zarafa.'),
    };

    return $dataTable;
}

1;
