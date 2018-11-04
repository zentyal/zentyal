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

package EBox::CGI::ActivationRequired;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use TryCatch;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new('title' => __('Activation Required'),
                                  'template' => 'activation.mas', %params);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $key = $self->param('key');

    if ($key) {
        try {
            my $url = EBox::Global->edition() eq 'trial-expired' ?
                        '/' : EBox::GlobalImpl::_packageInstalled('zentyal-custom') ?
                                '/ActivationSaveChanges?save=1' : '/Software/Welcome';
            my $sysinfo = EBox::Global->modInstance('sysinfo');
            my $license = $sysinfo->model('Edition');
            $license->set(key => $key);
            EBox::Sudo::rootWithoutException('apt update');
            $self->{redirect} = $url;
        } catch {
            $self->{params} = [ error => __("License key cannot be validated. Please try again or check your Internet connection.") ];
        }
    }
}

sub _menu
{
}

sub _top
{
}

sub _title
{
}

1;
