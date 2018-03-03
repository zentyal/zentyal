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

package EBox::Mail::CGI::Wizard::VirtualDomain;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Validate;
use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'mail/wizard/virtualdomain.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _processWizard
{
    my ($self) = @_;

    $self->_requireParam('vdomain', __('Mail virtual domain'));
    my $domain = $self->param('vdomain');

    unless ( EBox::Validate::_checkDomainName($domain) ) {
        throw EBox::Exceptions::External(__('Invalid virtual mail domain'));
    }

    my $global = EBox::Global->getInstance();
    my $mail = $global->modInstance('mail');
    my $model = $mail->model('VDomains');

    $model->addRow(vdomain => $domain, aliases => []);
}

1;
