package EBox::Squid::Model::ApplyAllowToAllExtensions;
#
use strict;
use warnings;

use base 'EBox::Squid::Model::ApplyAllowToAllBase';

use EBox::Global;
use EBox::Gettext;


sub new
{
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);
      bless( $self, $class );

      return $self;
}


sub elementsPrintableName
{
  my ($class) = @_;
  return __('extensions');
}


sub printableTableName
{
  my ($class) = @_;
  return __('Set policy for all extensions');
}


sub listModel
{
  my $squid = EBox::Global->modInstance('squid');
  return $squid->model('ExtensionFilter');
}


1;
