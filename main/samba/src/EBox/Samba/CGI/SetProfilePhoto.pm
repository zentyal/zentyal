# Copyright (C) 2018 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Samba::CGI::SetProfilePhoto;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;
use EBox::Samba::User;

# Core modules
use TryCatch;
use File::Basename;
use File::Copy;

# Group: Public methods

sub new # (cgi=?)
{
	my $class = shift;
	my %params = @_;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return $self;
}

# Group: Protected methods

# Method: _process
#
#      Upload a file which is defined by a single parameter. The file
#      is stored in <EBox::Config::tmp> directory with base name
#      equals to the base name from the user path.
#
# Overrides:
#
#      <EBox::CGI::Base::_process>
#
sub _process
{
    my $self = shift;

    my $request = $self->request();
    my $uploads = $request->uploads();
    my @entryKeys = keys %{$uploads};

    # We only take the first uploaded file found.
    my $upload = $uploads->{$entryKeys[0]};
    my $uploadedFile = $upload->path();
    my $username = $self->param('username');
    my $user = new EBox::Samba::User(samAccountName => $username);
    $user->setThumbnailPhoto($uploadedFile);
}

1;
