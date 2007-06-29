# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::CGI::CA::ShowForm;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox;

# Method: new
#
#       Constructor for ShowForm CGI.
#       Show a common form (one for revokation and other for renewal)
#
# Returns:
#
#       ShowForm - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    bless($self, $class);

    return $self;

  }

# Process the HTTP query

sub _process
  {

    my $self = shift;

    my $ca = EBox::Global->modInstance('ca');

    my @array = ();

    $self->_requireParam('cn', __('Common Name'));
    $self->_requireParam('action', __('Action'));

    my $cn = $self->param('cn');
    my $action = $self->param('action');

    if ($action eq "revoke") {
      $self->{template} = "ca/formRevoke.mas";
    } elsif ($action eq "renew") {
      $self->{template} = "ca/formRenew.mas";
    } else {
      throw EBox::Exceptions::External(__('Only revoke and renew actions are performed'));
    }

    my $cert = $ca->getCertificateMetadata(cn => $cn);

    if (not defined($cert) ) {
      # If the common name does NOT exist sent to Index.pm
      $self->{errorchain} = "CA/Index";
      throw EBox::Exceptions::External(__x("Common name: {cn} does NOT exist in database"
					   , cn => $cn));
    }

    push (@array, metaDataCert => $cert);
    push (@array, reasons => $ca->revokeReasons());
    push (@array, passRequired => $ca->passwordRequired());

    $self->{params} = \@array;

  }

1;
