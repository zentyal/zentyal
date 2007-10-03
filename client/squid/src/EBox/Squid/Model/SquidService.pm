package EBox::Squid::Model::SquidService;
#
use strict;
use warnings;

use base 'EBox::Common::Model::EnableForm';

sub new
  {
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless $self, $class;

    return $self;
  }



sub _table
{
  my ($self) = @_;

  my $table = EBox::Common::Model::EnableForm::_table($self);
  $table->{tableName} = $self->name;

  return $table;
}

sub name
{
  return 'SquidService';
}



1;
