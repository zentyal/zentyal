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
use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'openchange/wizard/provision.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    if (EBox::Global->modInstance('samba')->_adcMode() or
       (EBox::Global->modInstance('mail')->model('VDomains')->size() == 0)) {
        $self->skipModule();
        $self->{skip} = 1;
    } else {
        $self->SUPER::_process();
    }
}

sub _print
{
    my ($self) = @_;

    if ($self->{skip}) {
        $self->response()->body('<script type="text/javascript">window.location = "/SaveChanges?firstTime=1&noPopup=1&save=1"</script>');
    } else {
        $self->SUPER::_print();
    }
}

sub _processWizard
{
    my ($self) = @_;
    $self->_requireParam('orgName', __('Organization Name'));
    my $orgName = $self->param('orgName');
    $self->_requireParam('countryName', __('Country code'));
    my $countryName = $self->param('countryName');
    $self->_requireParam('localityName', __('City'));
    my $localityName = $self->param('localityName');
    $self->_requireParam('stateName', __('State'));
    my $stateName = $self->param('stateName');
    $self->_requireParam('expiryDays', __('Days to expire'));
    my $expiryDays = $self->param('expiryDays');

    my %certificateArgs =  (
        orgName => $orgName,
        countryName => $countryName,
        localityName => $localityName,
        stateName => $stateName,
        days => $expiryDays
    );

    my $ca = EBox::Global->modInstance('ca');
    $ca->checkCertificateFieldsCharacters(%certificateArgs);

    my $openchange = EBox::Global->modInstance('openchange');
    my $state = $openchange->get_state();
    $state->{provision_from_wizard} = \%certificateArgs;
    $openchange->set_state($state);
}

1;
