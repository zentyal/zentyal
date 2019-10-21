# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::SysInfo::CGI::SysInfoReport;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use TryCatch;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $self = $class->SUPER::new('title' => __('SmartAdmin'),
                                  'template' => '/sysinfo/report.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    unless (EBox::Global->communityEdition()) {
        $self->_runReportScript();
    }
    $self->{params} = $self->masonParameters();  
}

# Method: masonParameters
#
#      Overrides <EBox::CGI::ClientBase::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;
    my @params = ();
    @params = (
        'edition' => $self->_checkLicense(),
    );

    return \@params;
}

# Method: _checkLicense
#
# Returns:
#
#       Boolean - Indicates whether the installed version is a commercial one or not
sub _checkLicense
{
    my ($self) = @_;
    my $commercial = 0;
    unless (EBox::Global->communityEdition()) {
        $commercial = 1;
    }

    return $commercial;
}

sub _runReportScript
{
    my $cmd = EBox::Config::scripts() . "smart-admin-report";
    EBox::Sudo::root($cmd);
    EBox::info(EBox::Sudo::root($cmd));
}
1;