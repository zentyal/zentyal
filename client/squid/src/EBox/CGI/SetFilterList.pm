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

package EBox::CGI::Squid::SetFilterList;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = 'ebox-squid';
	bless($self, $class);
	return $self;
}

sub _process($)
{
	my $self = shift;

	my $squid = EBox::Global->modInstance('squid');
	$self->_requireParam('attrName', __("Attribute Name"));

	my $attrName = $self->param('attrName');

	my @attrs =  grep {s/^bool-//} @{$self->params()};

	my @allow;
	my @ban;

	for my $attr (@attrs) {
	  # If the deletion is done, don't push in any list
	  if (not $self->param("delete-$attr")) {
	    if ($self->param("bool-$attr")) {
	      push @ban, $attr;
	    } else {
	      push @allow, $attr;
	    }
	  } else {
	    $self->setMsg(__x("{attr} has been deleted successfully",
			     attr => $attr));
	  }
	}

	if ( $self->param("delete-all") eq "delete-all") {
	  @ban = ();
	  @allow = ();
	  if ( $attrName eq "extension" ) {
	    $self->setMsg(__("All file extensions have been deleted"));
	  } else {
	    $self->setMsg(__("All MIME types have been deleted"));
	  }
	}

	if($attrName eq "extension") {
	  $self->{chain} = "Squid/ExtensionsUI";
	  $squid->setAllowedExtensions(@allow);
	  $squid->setBannedExtensions(@ban);
	} elsif ($attrName eq "mimeType") {
	  $self->{chain} = "Squid/MimeTypesUI";
	  $squid->setAllowedMimeTypes(@allow);
	  $squid->setBannedMimeTypes(@ban);
	}

}

1;
