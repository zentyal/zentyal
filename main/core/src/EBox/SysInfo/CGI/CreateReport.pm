# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::SysInfo::CGI::CreateReport;

use base qw(EBox::CGI::ClientBase);

use EBox::Validate;
use EBox::Util::BugReport;
use EBox::Gettext;
use TryCatch;

sub _print
{
    my ($self) = @_;

    my $response = $self->response();
    $response->status(200);
    $response->content_type('text/plain; charset=utf-8');

    my $email = $self->unsafeParam('email');
    my $validEmail = EBox::Validate::checkEmailAddress($email);
    if (not $validEmail) {
        $response->body('ERROR ' . __('Invalid email address'));
        return;
    }

    my $description = $self->unsafeParam('description');
    $description .= "\n\nh2. Error\n\n";
    $description .= "<pre>\n";
    $description .= $self->unsafeParam('error');
    $description .= "\n</pre>";
    $description .= "\n\nh2. Trace\n\n";
    $description .= "<pre>\n";
    $description .= $self->unsafeParam('stacktrace');
    $description .= "\n</pre>";

    my $ticket = EBox::Util::BugReport::send($email,
                                             $description);

    $response->body('OK ' . $ticket);
}

sub requiredParameters
{
    my ($self) = @_;

    return ['email', 'description', 'error', 'stacktrace'];
}

1;
