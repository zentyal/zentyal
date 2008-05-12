# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::EBox::CurrentProgress;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::ProgressIndicator;

use Error qw(:try);


## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Upgrading'),
				      'template' => 'none',
				      @_);
	$self->{domain} = 'ebox';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

	$self->{params} = [];
}

sub _print($) {
	my $self = shift;

	my $progressId = $self->param('progress');
	my $progress = EBox::ProgressIndicator->retrieve($progressId);

	my $response;
	$response .= $progress->stateAsString();
	$response .= $self->modulesChangedStateAsString();

	print($self->cgi()->header(-charset=>'utf-8'));
	print $response;
}


sub modulesChangedStateAsString
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $state = $global->unsaved() ? 'changed' : 'notChanged';
    return "changed:$state";
}

1;
