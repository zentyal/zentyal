# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::Squid::Model::ApplyAllowToAllBase;
#
use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;


sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless( $self, $class );

    return $self;
}


# Method: setRow
#
# Overrides:
#
#      <EBox::Model::DataTable::setRow>
#
#

sub setRow
{
    my ($self, $force, %params) = @_;

    my $allowValue = $params{allowForAll} ? 1 : 0;


    my $listModel = $self->listModel();

    foreach my $id (@{ $listModel->ids()}) {
        my $row = $listModel->row($id);
        my $allowed = $row->elementByName('allowed');
        $allowed->setValue($allowValue);
        $listModel->setTypedRow($id, { allowed => $allowed } );
    }
    ;


# XXX update listModel
}



sub elementsPrintableName
{
    my ($class) = @_;
    return __('elements');
}

sub _tableDesc
{
    my ($self) = @_;


    my $printableName = __x('Allow all {elements}',
            elements => $self->elementsPrintableName,
            );

    my @tableDesc =
        (
         new EBox::Types::Boolean(
             fieldName      => 'allowForAll',
             printableName  => $printableName,
             editable       => 1,
             help           => __('Use this field to change the value of ' .
                    'all the above rows at once')
             ),
        );

    return \@tableDesc;
}

#  Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{

    my ($self) = @_;

    my $tableDesc = $self->_tableDesc();

    my $dataForm = {
        tableName          => $self->nameFromClass,
        printableTableName => $self->printableTableName,
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => $tableDesc,
    };

    return $dataForm;

}



sub Viewer
{
    return  '/ajax/squid/applyAllForm.mas';

}



# custom changeRowJS to update the list
sub changeRowJS
{
    my ($self, $editId, $page) = @_;

    my  $function = q{_applyAllForm_changeRows('%s', '%s', %s, '%s',}.
            q{'%s', %s, %s, %s);};



    my $listModel   = $self->listModel();
    my $changeViewListJS = $listModel->changeViewJS(
            changeType => 'changeList',
            editId     => 0,
            page       => 0,
            isFilter   => 0,


            );

    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();

    my $onCompleteJS =  <<END;
    function(t) {
        highlightRow( id, false);
        stripe('dataTable', 'even', 'odd');
        $changeViewListJS;
    }
END


    my $JS = sprintf ($function,
            $table->{'actions'}->{'editField'},
            $table->{'tableName'},
            $fields,
            $table->{'gconfdir'},
            $editId,
            $page,
            0, # force
            $onCompleteJS
            );

    return $JS;
}



1;
