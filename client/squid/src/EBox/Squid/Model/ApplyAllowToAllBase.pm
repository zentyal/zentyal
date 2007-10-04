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
  EBox::debug("allow value $allowValue");


  my $listModel = $self->listModel();

  my $rows_r = $listModel->rows();
  foreach my $row (@{ $rows_r }) {
    my $id       = $row->{id};
    my $allowed = $row->{valueHash}->{allowed};
    $allowed->setValue($allowValue);
    use Data::Dumper;


    $listModel->setTypedRow($id, { allowed => $allowed } );
  }

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
#			      defaultValue   => 1,
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
#                      class              => 'dataForm',
                     };

      return $dataForm;

  }



sub Viewer
{
  return  '/ajax/squid/applyAllForm.mas';

}


1;
