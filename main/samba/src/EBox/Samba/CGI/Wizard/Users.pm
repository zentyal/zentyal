# Copyright (C) 2010-2014 Zentyal S.L.
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
use TryCatch;
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

    my $mode = $self->param('mode');

    if ($mode eq 'standalone') {
        $self->_processStandalone();
    } elsif ($mode eq 'join') {
        $self->_processJoinADC();
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

sub _processJoinADC
{
    my ($self) = @_;

    $self->_requireParam('realm', __('Domain Name'));
    $self->_requireParam('dcfqdn', __('Domain controller FQDN'));
    $self->_requireParam('dnsip', __('Domain DNS server IP'));
    $self->_requireParam('adminAccount', __('Administrator account'));
    $self->_requireParam('password', __('Administrator password'));
    $self->_requireParam('workgroup', __('NetBIOS domain name'));
    $self->_requireParam('netbiosName', __('NetBIOS computer name'));

    my $domain = $self->param('realm');
    my $dcfqdn = $self->param('dcfqdn');
    my $dnsip = $self->param('dnsip');
    my $adminAccount = $self->param('adminAccount');
    my $password = $self->param('password');
    my $workgroup = $self->param('workgroup');
    my $netbiosName = $self->param('netbiosName');

    if ($domain) {
        EBox::info('Setting the host domain');

        # Write the domain to sysinfo model
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $domainModel = $sysinfo->model('HostName');
        my $row = $domainModel->row();
        $row->elementByName('hostdomain')->setValue($domain);
        $row->store();
    }

    my $samba = EBox::Global->modInstance('samba');
    my $provision = $samba->getProvision();

    # Resolve DC FQDN to an IP if needed
    my $adServerIp = $provision->checkAddress($dnsip, $dcfqdn);

    # Check DC is reachable
    $provision->checkServerReachable($adServerIp);

    # Check DC functional levels > 2000
    $provision->checkFunctionalLevels($adServerIp);

    # Check RFC2307 compliant schema
    $provision->checkRfc2307($adServerIp, $adminAccount, $password);

    # Check local realm matchs remote one
    $provision->checkLocalRealmAndDomain($adServerIp);

    # Check clock skew
    $provision->checkClockSkew($adServerIp);

    # Check no DNS zones in main domain partition
    $provision->checkDnsZonesInMainPartition($adServerIp, $adminAccount, $password);

    # Check forest only contains one domain
    $provision->checkForestDomains($adServerIp, $adminAccount, $password);

    # Check there are not trust relationships between domains or forests
    $provision->checkTrustDomainObjects($adServerIp, $adminAccount, $password);

    # Check the netbios domain name
    $provision->checkADNebiosName($adServerIp, $adminAccount, $password, $workgroup);

    my $settings = $samba->model('DomainSettings');
    $settings->setRow(
        0, # no force mode
        mode => EBox::Samba::Model::DomainSettings::MODE_ADC(),
        realm => $domain,
        dcfqdn => $dcfqdn,
        dnsip => $dnsip,
        adminAccount => $adminAccount,
        password => $password,
        workgroup => $workgroup,
        netbiosName => $netbiosName
    );
}

1;
