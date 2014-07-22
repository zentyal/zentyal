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

package EBox::Samba::CGI::Wizard::Users;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use TryCatch::Lite;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'samba/wizard/users.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _processWizard
{
    my ($self) = @_;
    if ($self->param('standalone')) {
        $self->_processStandalone();
    } else {
        $self->_processExternalAD();
    }
}

sub _processStandalone
{
    my ($self) = @_;
    my $domain = $self->param('domain');
    if ($domain) {
        EBox::info('Setting the host domain');

        # Write the domain to sysinfo model
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $domainModel = $sysinfo->model('HostName');
        my $row = $domainModel->row();
        $row->elementByName('hostdomain')->setValue($domain);
        $row->store();
    }
}

sub _processExternalAD
{
    my ($self) = @_;
    $self->_requireParam('dcHostname', __('Active Directory hostname'));
    $self->_requireParam('dcUser', __('Administrative user'));
    $self->_requireParam('dcPassword', __('User password'));
    $self->_requireParam('dcPassword2', __('Confirm user password'));
    my $dcPassword = $self->unsafeParam('dcPassword');
    my $dcPassword2 = $self->unsafeParam('dcPassword2');
    if ($dcPassword ne $dcPassword2) {
        throw EBox::Exceptions::External(__('User password and confirm user password does not match'));
    }

    my $users = EBox::Global->modInstance('samba');
    my $mode = $users->model('Mode');
    $mode->setRow(
        0, # no force mode
        mode       => $users->EXTERNAL_AD_MODE(),
        dcHostname => $self->param('dcHostname'),
        dcUser => $self->param('dcUser'),
        dcPassword => $dcPassword,
        dcPassword2 => $dcPassword2
       );
}

1;
