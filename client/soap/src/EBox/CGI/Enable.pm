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

package EBox::CGI::SOAP::Enable;

# This CGI enables or disables the SOAP communication

use strict;
use warnings;

# It's a CGI
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Config;

# Constructor: new
#
#     Overrides <EBox::CGI::Base::new> constructor
#
sub new
  {

      my $class = shift;
      my $self = $class->SUPER::new('title' => __('Enable SOAP service'),
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

      return [qw(active change)];

  }

# Method: actuate
#
#     Overrides <EBox::CGI::Base::actuate> method
#
sub actuate
  {

      my ($self) = @_;

      $self->setChain('SOAP/Index');

      my $gl = EBox::Global->getInstance();
      my $soap = $gl->modInstance('soap');

      # Set enabled attribute
      my $userEnable = $self->param('active') eq 'yes' ? 1 : '';
      $soap->setEnabled( $userEnable );

      # Delete params since it works alright (FIXME: setChain hell)
      $self->cgi()->delete('active');
      $self->cgi()->delete('change');

  }

1;
