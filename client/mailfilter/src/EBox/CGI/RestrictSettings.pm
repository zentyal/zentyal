# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::MailFilter::RestrictSettings;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'MailFilter', @_);
	$self->{domain} = "ebox-mailfilter";	
	bless($self, $class);
	return $self;
}

sub trimArray() # (@array)
{
   my $self = shift;
   my @array = @_;
   my @ret = ();
   foreach my $elmnt (@array) {
      defined ($elmnt) or next;
      ($elmnt ne '') or next;
      push(@ret, $elmnt);
   }
   return @ret;
}

sub _process($) {
	my $self = shift;
	my $mfilter = EBox::Global->modInstance('mailfilter');

	$self->_requireParam('tlist', __('list type'));
	my $list = $self->param('tlist');
	$self->{redirect} = "MailFilter/Index?menu=restrict&tlist=$list";	
	
	my @oldres = @{$mfilter->accountsBypassList($list)};

	if (defined($self->param('Res2Non'))) {
		my @del = $self->trimArray($self->param('res'));
		(@del < 1) and return;
		my @newres = ();
		foreach my $addr (@oldres) {
			unless (grep(/^$addr$/, @del)) {
				push(@newres, $addr);
			}
		}
      $mfilter->setAccountsBypassList($list, \@newres);
   } elsif (defined($self->param('Non2Res'))) {
      my @add = $self->trimArray($self->param('nonres'));
      (@add < 1) and return;
      push(@oldres, @add);
      $mfilter->setAccountsBypassList($list, \@oldres);
   } elsif (defined($self->param('domainCheckBox'))) {
		my $mail = EBox::Global->modInstance('mail');
		my @domain = $mail->{'vdomains'}->vdomains();
		my @list = ("@".$domain[0]);
      $mfilter->setAccountsBypassList($list, \@list);
	} else {		
		my @empty = ();
      $mfilter->setAccountsBypassList($list, \@empty);
	}

}

1;
