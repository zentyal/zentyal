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

package EBox::CGI::CA::DownloadKeys;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for DownloadKeys CGI
#
# Returns:
#
#       DownloadKeys - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title'    => __('Certification Authority Management'),
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

    # Check if the CA infrastructure has been created
    my @array = ();

    $self->_requireParam('cn', __('Common Name') );

    my $cn = $self->param('cn');

    my $keys = $ca->getKeys($cn);

    my $zipfile = EBox::Config->tmp() . "keys.tar.gz"
      if ( defined($keys->{privateKey}) );

    if ($zipfile) {
      my $ret = system("tar cvzf $zipfile $keys->{privateKey} $keys->{publicKey}");
      if ($ret != 0) {
	throw EBox::Exceptions::External(__("Error creating file") . ": $!"));
      }
      $self->{downfile} = $zipfile
    } else {
      $self->{downfile} = $keys->{publicKey};
    }

  }

sub _print
  {
    my $self = shift;

    if ($self->{error} or not defined($self->{downfile})) {
      $self->SUPER::_print;
      return;
    }

    open( my $keyFile, $self->{downfile} )
      or throw EBox::Exceptions::Internal("Could NOT open key file.");

    print($self->cgi()->header(-type => 'application/octet-stream',
			       -attachment => $self->{downfile}));

    while(<$keyFile>) {
      print $_;
    }

    close($keyFile);

  }

1;
