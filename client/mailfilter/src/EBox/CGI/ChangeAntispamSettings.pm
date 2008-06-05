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

package EBox::CGI::MailFilter::ChangeAntispamSettings;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

use Perl6::Junction qw(any);


my @settings = qw(spamThreshold spamSubjectTag bayes autoWhitelist autolearn 
autolearnHamThreshold autolearnSpamThreshold spamAccountActive hamAccountActive);
my @unsafeParamSettings = qw(spamSubjectTag);


## arguments:
## 	title [required]
sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title' => 'Mail filter', @_);
  
  $self->setRedirect("MailFilter/Index?menu=antispam");	
  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}


sub optionalParameters
{
  return [@settings, 'change'];
}


sub actuate {
  my ($self) = @_;
  my $mailfilter= EBox::Global->modInstance('mailfilter');
  my $antispam  = $mailfilter->antispam;
 
  my $anyUnsafeParam = any @unsafeParamSettings;

  foreach my $setting (@settings) {
    my $newValue;
    if ($setting eq $anyUnsafeParam) {
      $newValue = $self->unsafeParam($setting);
    }
    else {
      $newValue = $self->param($setting);      
    }

    next if $newValue eq $antispam->$setting();

    my $setter = "set\u$setting";
    $antispam->$setter($newValue);
  }
  

}

1;
