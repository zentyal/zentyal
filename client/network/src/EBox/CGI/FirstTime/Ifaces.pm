package EBox::CGI::Network::FirstTime::Ifaces;
# Description:
use strict;
use warnings;
use EBox::Gettext;

use base 'EBox::CGI::Network::Ifaces';


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Network interfaces'),
				      'template' => '/network/ifaces.mas',
				      @_);
	$self->{domain} = 'ebox-network';
	bless($self, $class);
	return $self;
}

sub _process
{
  my $self = shift;

  $self->setMsg( __("After the initial config you can revisit this page at Network/Interfaces in the menu"));

  $self->{params} = $self->masonParameters();
}


1;
