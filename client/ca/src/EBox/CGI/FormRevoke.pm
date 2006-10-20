# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::CGI::CA::ShowRevoke;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for ShowRevoke CGI
#
# Returns:
#
#       Index - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title'    => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    $self->{template} = "CA/formRevoke";
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

    my $cn = $self->param('cn');

    my $arrayRef = $ca->listCertificates($cn);

    if ($#{$arrayRef} == 0 ) {
      throw EBox::Exceptions::External(__x("Common name: {cn} does NOT exist in database"
					   , cn => $cn));
    }
    push (@array, $arrayRef->[0]);

    $self->{params} = \@array;

  }

1;
