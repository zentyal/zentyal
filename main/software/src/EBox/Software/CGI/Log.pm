# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Software::CGI::Log;

use EBox;
use EBox::Util::BugReport;
use EBox::Gettext;
use File::Slurp;
use TryCatch;

use base 'EBox::CGI::ClientBase';

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub actuate
{
    my ($self) = @_;

    $self->{downfilename} = 'software.log';
}

sub _print
{
    my ($self) = @_;

    if ($self->{error}) {
        $self->SUPER::_print;
        return;
    }

    my $response = $self->response();
    $response->status(200);
    $response->content_type('application/octet-stream');
    $response->header('Content-Disposition' => 'attachment; filename="' . $self->{downfilename} . '"');
    my @brokenPackages = EBox::Util::BugReport::brokenPackagesList();
    $response->body(EBox::Util::BugReport::dumpSoftwareLog(@brokenPackages));
}

1;
