# Copyright (C) 2009 Warp Networks S.L.
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


package EBox::Squid::Model::UseDefaultExtensionFilter;
use base 'EBox::Model::DataForm';

use strict;
use warnings;


use EBox::Gettext;

use EBox::Types::Boolean;



# eBox exceptions used 
use EBox::Exceptions::External;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#

# 
sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Boolean(
                  fieldName => 'useDefault',
                  printableName => __('Use default profile configuration'),
                  defaultValue => 0,
                  editable     => 1,
          ),


        );

    my $dataForm = {
        tableName          => 'UseDefaultExtensionFilter',
        printableTableName => __('Use default profile for extension filtering'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        class              => 'dataForm',
    };



    return $dataForm;
}


sub modelsToUpdate
{
    my ($self) = @_;

    my @modelNames = (
                      'FilterGroupExtensionFilter', 
                      'FilterGroupApplyAllowToAllExtensions'
                     );

    my $squid = EBox::Global->modInstance('squid');
    my @models = map {  $squid->model($_) } @modelNames;

    return \@models;
}

sub Viewer
{
    return  '/ajax/squid/applyAllForm.mas';
 #   return  '/ajax/squid/useDefaultForm.mas';

}


# custom changeRowJS to update the other sections
sub changeRowJS
{
    my ($self, $editId, $page) = @_;



    my @modelsToUpdate = @{ $self->modelsToUpdate };
    my @changeViewJS;
    foreach my $model (@modelsToUpdate) {
        my $changeViewJS = $model->changeViewJS(
            changeType => 'changeList',
            editId     => 0,
            page       => 0,
            isFilter   => 0,
            );

        push @changeViewJS, $changeViewJS;
    }


    my $table = $self->table();
    my $fields = $self->_paramsWithSetterJS();
    $fields =~ s/'/"/g;

    my $onCompleteJS =  <<END;
    function(t) { 
        highlightRow( id, false);
        stripe("dataTable", "#ecf5da", "#ffffff");
END

    foreach my $changeViewJS (@changeViewJS) {
        $onCompleteJS .= "\n$changeViewJS;";
    }
    $onCompleteJS .= "\n}";


    my  $function = 'applyAllChangeRows("%s", "%s", %s, "%s",'.
            '"%s", %s, %s, %s)';
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

