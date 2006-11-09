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

package EBox::CGI::Squid::MimeTypesUI;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('HTTP Proxy'),
				      'template' => 'squid/filterTable.mas',
				      @_);
	$self->{domain} = 'ebox-squid';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

	my $squid = EBox::Global->modInstance('squid');
	my @filterParam;
	push (@filterParam, 'elements'      => $squid->hashedMimeTypes());
	push (@filterParam, 'title'         => __("Configure allowed MIME types"));
	push (@filterParam, 'name'          => "mimeType");
	push (@filterParam, 'printableName' => __("MIME type"));

	my @mimeTypes = @{$squid->ianaMimeTypes()};
	pop( @mimeTypes );
	my $mimeTypesStr = join(', ', @mimeTypes);
	$mimeTypesStr .= __(' or something starting with "x-".');
	push (@filterParam, 'helpMessage'   => __x("Add a new MIME type with the following syntax: type/subtype " .
						   "Where type can be: {types}",
						   types => $mimeTypesStr));

	$self->{params} = \@filterParam;
}

1;
