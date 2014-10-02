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

package EBox::RemoteServices::CGI::Community::Register;
use base qw(EBox::CGI::ClientBase);

# CGI to present the community registration form

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
        title    => __('Configuration Backup'),
        template => '/backupTabs.mas',
        @_);

    bless($self, $class);
    return $self;
}

sub optionalParameters
{
    return ['selected'];
}

sub masonParameters
{
    my ($self) = @_;

    my @params = ();

    my $global = EBox::Global->getInstance();
    my $sysinfo = $global->modInstance('sysinfo');
    push @params, (fqdn => $sysinfo->hostName());
    push @params, (selected => 'remote');
    push @params, (component => 'remoteservices/Community/register.mas');

    return \@params;
}

1;
