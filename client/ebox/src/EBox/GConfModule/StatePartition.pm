package EBox::GConfModule::StatePartition;
#
use strict;
use warnings;

use base 'EBox::GConfModule::Partition';



sub new
{
  my ($class, $base, $fullModule) = @_;

  my $self = $class->SUPER::new($base, $fullModule);
  bless $self, $class;

  return $self;
}

sub _checkBaseDirExists
{
  my ($class, $fullModule, $base) = @_;
  return $fullModule->st_dir_exists($base);
}


sub _fullModuleMethod
{
  my ($self, $method, @params) = @_;
  $method = 'st_' . $method; # to convert methods in state methods
  return $self->fullModule->$method(@params);
}


1;
