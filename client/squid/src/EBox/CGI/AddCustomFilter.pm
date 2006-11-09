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

package EBox::CGI::Squid::AddCustomFilter;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox;

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
	$self->_requireParam('name', __("Name"));
	$self->_requireParam('deny', __("Deny"));

	# So far it could be extension or mimeType attribute
	my $attrName = $self->param('attrName');
	my $name = $self->param('name');
	my $deny = $self->param('deny');

	if ( $attrName eq "extension" ) {
	  $self->{chain} = "/Squid/ExtensionsUI";
	} elsif ( $attrName eq "mimeType" ) {
	  $self->{chain} = "/Squid/MimeTypesUI";
	}

	# Check parameters
	if (length ($name) > 64 ) {
	  throw EBox::Exceptions::External(__x("New {type} SHOULD be lower than {number} characters",
					      type => ($attrName eq "extension" ? __("Extension") : __("MIME type")),
					      number => 64));
	}

	# Delete undesirable spaces
	$name =~ s/^( )*//;
	$name =~ s/( )*$//;

	# MIME type case is quite difficult
	if ( $attrName eq "mimeType" ) {
	  if ( $name !~ m/\w\/\w/ ) {
	    throw EBox::Exceptions::External(__x('The {type} SHOULD have the following syntax: "word/word"',
						type => __("MIME type")));
	  }
	  my ($type, $subtype) = $name =~ m/(\w+)\/(\w+)/;

	  if ( not grep { $type =~ m/$_/ } @{$squid->ianaMimeTypes()} ) {
	    throw EBox::Exceptions::External(__x('The {type} SHOULD be in IANA type. ' .
						 'Check this link: {url} for details',
					       type => __("MIME type"), 
					       url  => "http://www.iana.org/assignments/media-types/index.html"));
	  }
	}

	if ( $attrName eq "extension" ) {
	  my $banExt = $squid->bannedExtensions();
	  my $allowExt = $squid->allowedExtensions();
	  if (not grep { $_ eq $name } @{$banExt}
	      and not grep { $_ eq $name} @{$allowExt} ) {
	    if ($deny) {
	      # NOT found in ban extensions, we could add it
	      push( @{$banExt}, $name );
	      $squid->setBannedExtensions(@{$banExt});
	    } else {
	      push( @{$allowExt}, $name );
	      $squid->setAllowedExtensions(@{$allowExt});
	    }
	    $self->setMsg(__("File extension added correctly"));
	  } else {
	    $self->setError(__("File extension is already in the list"));
	  }
	} elsif ( $attrName eq "mimeType" ) {
	  my $banMT = $squid->bannedMimeTypes();
	  my $allMT = $squid->allowedMimeTypes();

	  if (not grep {$name eq $_} @{$banMT} 
	      and not grep { $name eq $_ } @{$allMT} ) {
	    if ($deny) {
	      # NOT found in ban extensions, we could add it
	      push( @{$banMT}, $name );
	      $squid->setBannedMimeTypes(@{$banMT});
	    } else {
	      push( @{$allMT}, $name );
	      $squid->setAllowedMimeTypes(@{$allMT});
	    }
	    $self->setMsg(__("MIME type added correctly"));
	  } else {
	    $self->setError(__("MIME type is already in the list"));
	  }
	}
      }



1;
