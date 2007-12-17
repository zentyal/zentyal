package EBox::Model::ImageControl;
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
 my %paramsCopy = %params;

 $self->SUPER::setRow($force, %params);

  my $imageModel = $self->imageModel();
  $imageModel->setRow($force, %paramsCopy);
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
		  #                      class              => 'dataForm',
		 };
  
  return $dataForm;
}




sub _tableDesc
{
  my ($self) = @_;
  my $tableDesc;
  
  my $imageModel = $self->imageModel();
  my $imageTable = $imageModel->_table();

  my $imgTableDesc_r   = $imageTable->{tableDescription};
#   foreach my $field (values %{ $imgTableDesc_r }) {
#     $field
#   }


#   return $tableDesc;

  return $imgTableDesc_r;
}


sub _modelDomain
{
  my ($self) = @_;

  my $imageModel = $self->imageModel();
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


  my $table = $self->imageModel->table();
  my $fields = $self->_paramsWithSetterJS();

  $fields =~ s/'/"/g; 


  my $ownJS = sprintf ($function, 
			 $table->{'actions'}->{'editField'},
			 $table->{'tableName'},
			 $fields,
			 $table->{'gconfdir'},
		         0, # force
		   );


  my $JS = "var $functionName = function() { $superJS; $ownJS; return false   }; $functionName()";

  return $JS;

}


sub printableTableName
{
  return '';
}

sub imageModel
{
  throw EBox::Exceptions::NotImplemented;
}

1;
