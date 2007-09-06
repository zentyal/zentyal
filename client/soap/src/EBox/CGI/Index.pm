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

package EBox::CGI::SOAP::Index;

# This CGI show the index for the SOAP module

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
#        Overrides <EBox::CGI::ClientBase::new> method
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(
                                    'title'    => __('Control center communication'),
                                    'template' => 'soap/index.mas',
                                    @_,
                                   );

      $self->{domain} = 'ebox-soap';
      bless ($self, $class);

      return $self;

  }

# Method: optionalParameters
#
#     Override <EBox::CGI::Base::optionalParameters> method
#
sub optionalParameters
  {

      my ($self) = @_;

      return [qw(testResult)];

  }

# Method: masonParameters
#
#     Override <EBox::CGI::Base::masonParameters> method
#
sub masonParameters
  {

      my ( $self ) = @_;

      my $gl = EBox::Global->getInstance();
      my $soap = $gl->modInstance('soap');

      # Set the template (index.mas) parameters
      my @tplParams = ();
      push ( @tplParams, 'uploaded'  => $soap->bundleUploaded() );
      push ( @tplParams, 'active'    => $soap->enabled() ? 'yes' : 'no' );
      push ( @tplParams, 'commonName' => $soap->eBoxCN() );
      if ( defined ( $self->param('testResult') )) {
          push ( @tplParams, 'testResult' => $self->param('testResult'));
      }

      return \@tplParams;

  }

1;
