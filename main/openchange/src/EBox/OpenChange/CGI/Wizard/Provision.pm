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

package EBox::OpenChange::CGI::Wizard::Provision;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Validate;
use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'openchange/wizard/provision.mas', @_);
    bless($self, $class);
    return $self;
}

sub _processWizard
{
    my ($self) = @_;

    $self->_requireParam('orgName', __('Organization Name'));
    my $orgName = $self->param('orgName');

    my $openchange = EBox::Global->modInstance('openchange');
    my $state = $openchange->get_state();
    $state->{provision_from_wizard} = { orgName => $orgName };
    $openchange->set_state($state);
}

1;
