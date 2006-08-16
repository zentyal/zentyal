package EBox::CGI::Network::FirstTime::Ifaces;
# Description:
use strict;
use warnings;
use EBox::Gettext;

use base 'EBox::CGI::Network::Ifaces';


sub _process
{
  my $self = shift;

  $self->setMsg( __("After the initial config you can revisit this page at Network/Interfaces in the menu"));
  $self->SUPER::_process(@_);

}


1;
