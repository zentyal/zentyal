package EBox::Backup::CGI::DoBackup;
# CGI action for backup
use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Backup;
use EBox::Backup::OpticalDiscDrives;
use Perl6::Junction qw(any);

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
  my ($self) = @_;
  return ['media', 'doBackup'];
} 


sub actuate
{
  my ($self) = @_;
  my $backup = EBox::Global->modInstance('backup');

  my @backupParams = ();
  my $media = $self->param('media');
  $self->_checkMedia($media);
  push @backupParams, (media => $media);

  $backup->backup(@backupParams);

  $self->setMsg(__('Configuration backup completed'));
}


sub  _checkMedia
{
  my ($self, $media) = @_;

  if ($media ne any(EBox::Backup::OpticalDiscDrives::allowedMedia())) {
    throw EBox::Exceptions::External(__x('This computer has not any device capable of writing {media}', media => $media));
  }

} 

1;
