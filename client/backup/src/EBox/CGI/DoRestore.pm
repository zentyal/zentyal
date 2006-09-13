package EBox::Backup::CGI::DoBackup;
# CGI action for backup
use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Backup;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Backup configuration'),
				      @_);
	$self->{domain} = "ebox-ntp";	
	$self->{redirect} = "Backup/Index.pm";
	bless($self, $class);
	return $self;
}



sub mandatoryParameters
{
  return ['doRestore'];
}

sub actuate
{
  my ($self) = @_;

  my $backup = EBox::Global->modInstance('backup');
  $backup->restore();

  $self->setMsg(__('Configuration restored'));
}



1;
