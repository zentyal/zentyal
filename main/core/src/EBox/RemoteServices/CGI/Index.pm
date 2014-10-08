# Copyright (C) 2014 Zentyal S.L.
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

package EBox::RemoteServices::CGI::Index;
use base qw(EBox::CGI::ClientBase);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use Cwd qw(realpath);
use HTTP::Date;
use Plack::Util;
use Sys::Hostname;
use TryCatch::Lite;


sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
                      'template' => 'remoteservices/index.mas',
                      @_);

    bless($self, $class);
    return $self;
}


sub requiredParameters
{
    my ($self) = @_;
    return [];
}

sub optionalParameters
{
    my ($self) = @_;
    return [];
}

sub actuate
{
    my ($self) = @_;
}

sub masonParameters
{
    my ($self) = @_;

    my @params = ();

    my $global = EBox::Global->getInstance();
    my $remoteservices = $global->modInstance('remoteservices');
    if (not $remoteservices->commercialEdition()) {
        $self->{template} = '/error.mas';
        return [error => 'Subscribe server is only available for commercial editions'];
    }
    

    my %context = (username => $remoteservices->username(),
                   subscriptionInfo => $remoteservices->subscriptionInfo(),
                   serverName => EBox::Global->modInstance('sysinfo')->hostName(),
                  );

    return [context => \%context];
}

1;
