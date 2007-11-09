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

package EBox::CGI::Controller::Uploader;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;

use Error qw(:try);

sub new # (cgi=?)
{
	my $class = shift;
	my %params = @_;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return  $self;
}


sub _process
{
    my $self = shift;

    my $params = $self->params();
    use Data::Dumper;
    EBox::debug(Dumper($params));

    my $filePathParam = $params->[0];
    my $uploadedFile = $self->upload($filePathParam);
    EBox::debug("uploaded file $uploadedFile");

}

1;
