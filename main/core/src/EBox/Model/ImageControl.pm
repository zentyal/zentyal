# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Model::ImageControl;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Exceptions::NotImplemented;

sub new
{
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);
      bless( $self, $class );

      return $self;
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

    my $tableDesc   = $self->_tableDesc();
    my $modelDomain = $self->_modelDomain();

    my $dataForm = {
                    tableName          => $self->nameFromClass,
                    printableTableName => $self->printableTableName,
                    modelDomain        => $modelDomain,
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => $tableDesc,
                    messages           => $self->_messages(),
                    #                      class              => 'dataForm',
                   };

    return $dataForm;
}

sub _messages
{
    my ($self) = @_;

    return {
            'add'       => undef,
            'del'       => undef,
            'update'    => undef,
           };
}

sub _tableDesc
{
    throw EBox::Exceptions::NotImplemented;
}

sub _modelDomain
{
    my ($self) = @_;

    my $imageModel = $self->_imageModel();
    my $imageTable = $imageModel->_table();

    return  $imageTable->{modelDomain};
}

sub Viewer
{
    return  '/ajax/imageControl.mas';
}

# custom changeRowJS to update the list
sub changeRowJS
{
    my ($self, $editId, $page) = @_;

    my $functionName = $self->name . 'Update';

    my $superJS = $self->SUPER::changeRowJS($editId, $page);

    my  $function = 'applyChangeToImage("%s", "%s", %s, "%s")';

    my $table = $self->_imageModel->table();
    my $fields = $self->_paramsWithSetterJS();

    $fields =~ s/'/"/g;

    my $ownJS = sprintf ($function,
                         $table->{'actions'}->{'editField'},
                         $table->{'tableName'},
                         $fields,
                         $table->{'confdir'},
                         0, # force
                        );

    my $JS = "var $functionName = function() { $superJS; $ownJS; return false   }; $functionName()";

    return $JS;

}

sub printableTableName
{
  return '';
}

sub _imageModel
{
    throw EBox::Exceptions::NotImplemented;
}

1;
