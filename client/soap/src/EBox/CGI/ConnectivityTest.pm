# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::CGI::SOAP::ConnectivityTest;

# Class: EBox::CGI::SOAP::ConnectivityTest
#
# This CGI is intended to do the connectivity test
#

use strict;
use warnings;

# It's a CGI
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;

# Constructor: new
#
#     Overrides <EBox::CGI::Base::new> constructor
#
sub new
  {

      my $class = shift;
      my $self = $class->SUPER::new('title' => __('Connectivity test'),
                                    @_);

      $self->{domain} = 'ebox-soap';
      bless($self, $class);

  }

# Method: requiredParameters
#
#     Overrides <EBox::CGI::Base::requiredParameters> method
#
sub requiredParameters
  {

      my ($self) = @_;

      return [qw(test)];

  }

# Method: actuate
#
#     Overrides <EBox::CGI::Base::actuate> method
#
sub actuate
  {

      my ($self) = @_;

      # Return whenever to the Index
      $self->setChain('SOAP/Index');

      my $gl = EBox::Global->getInstance();
      my $soap = $gl->modInstance('soap');

      # Delete the previously uploaded file
      my $lossPercent = $soap->connectivityTest();

      # Delete params since it works alright (FIXME: setChain hell)
      $self->cgi()->delete('test');
      # Pass the parameter to the Index.pm
      $self->cgi()->param( 'testResult' => $lossPercent );
      $self->keepParam('testResult');

  }

1;
