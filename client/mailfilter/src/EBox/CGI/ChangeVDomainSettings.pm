# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::MailFilter::ChangeVDomainSettings;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use Perl6::Junction qw(any);


my @settings = qw(antivirus antispam spamThreshold defaultSpamThreshold);


## arguments:
## 	title [required]
sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title' => 'Mail filter', @_);
  
  $self->setRedirect("Mail/VDomains");	
  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}



sub requiredParameters
{
  return ['vdomain'];
}

sub optionalParameters
{
  return [@settings, 'change'];
}


sub actuate {
  my ($self) = @_;
  my $vdomain = $self->param('vdomain');
  $self->setRedirect("/Mail/EditVDomain?vdomain=$vdomain&menu=1");


  my $mailfilter= EBox::Global->modInstance('mailfilter');
  my $antivirus = $mailfilter->antivirus();
  my $antispam  = $mailfilter->antispam();

 
  my $antivirusService =  $self->param('antivirus');
  if (defined $antivirusService) {
    if ($antivirusService != $antivirus->vdomainService($vdomain)) {
      $antivirus->setVDomainService($vdomain, $antivirusService);

    }
  }
  
  my $antispamService =  $self->param('antispam');
  if (defined $antispamService) {
    if ($antispamService != $antispam->vdomainService($vdomain)) {
      $antispam->setVDomainService($vdomain, $antispamService);

    }
  }

  my $defaultSpamThreshold  =  $self->param('defaultSpamThreshold');
  my $threshold             =  $self->param('spamThreshold');
  if (not $defaultSpamThreshold) {
    if ($threshold != $antispam->vdomainSpamThreshold($vdomain)) {
      $antispam->setVDomainSpamThreshold($vdomain, $threshold);

    }
  }
  else {
    if ($antispam->vdomainSpamThreshold($vdomain)) {
      $antispam->setVDomainSpamThreshold($vdomain, undef);
    }
  }

}

1;
