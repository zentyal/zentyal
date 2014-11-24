# Copyright (C) 2014 Zentyal S. L.
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

# Class: EBox::OpenChange::Model::VDomains
#
#   Helper table to aid the users to configure Virtual Domains
#

package EBox::OpenChange::Model::VDomains;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::MultiStateAction;
use EBox::Types::Link;
use EBox::Exceptions::Internal;

sub new
{
    my $class = shift;

    my $self =  $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my $tableHead = [
        new EBox::Types::Text(
            fieldName       => 'vdomain',
            printableName   => __('Virtual domain'),
            size            => '20',
            editable        => 0,
        ),
        new EBox::Types::Boolean(
            fieldName       => 'zentyalManaged',
            printableName   => __('DNS domain managed by Zentyal'),
            volatile        => 1,
            acquirer        => \&_zentyalManagedAcquirer,
            hiddenOnSetter  => 1,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas'
        ),
        new EBox::Types::Boolean(
            fieldName       => 'certificate',
            printableName   => __('Certificate in place'),
            volatile        => 1,
            acquirer        => \&_certificateAcquirer,
            hiddenOnSetter  => 1,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas'
        ),
        new EBox::Types::Boolean(
            fieldName       => 'autodiscoverRecord',
            printableName   => __('Auto Discover DNS record'),
            volatile        => 1,
            acquirer        => \&_autodiscoverRecordAcquirer,
            storer          => \&_autodiscoverRecordStorer,
            editable        => \&_autodiscoverIsEditable,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas',
            help            => __('Enable the Auto Discover service, your ' .
                                  'MAPI client will automatically find ' .
                                  'server configuration. To enable this ' .
                                  'option the domain has to be handled by ' .
                                  'Zentyal DNS.'),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'rpcproxy_http',
            printableName   => __('Outlook® Anywhere (no SSL)'),
            editable        => 1,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas',
            help            => __('RPC over HTTP access. MAPI/RPC over HTTP, '.
                                  'non-SSL version. By default, HTTP protocol ' .
                                  'is blocked by Zentyal firewall.'),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'rpcproxy_https',
            printableName   => __('Outlook® Anywhere (SSL)'),
            editable        => \&_sslRpcProxyIsEditable,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas',
            help            => __('RPC over HTTPS access. MAPI/RPC over ' .
                                  'HTTP, SSL enabled version. To enable ' .
                                  'this option you have to "Issue ' .
                                  'Certificate" first.'),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'webmail_http',
            printableName   => __('Webmail'),
            editable        => 1,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/webmailViewer.mas',
            help            => __('Webmail and groupware platform. Non-SSL ' .
                                  'version. By default HTTP protocol is ' .
                                  'blocked by Zentyal firewall.'),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'webmail_https',
            printableName   => __('HTTPS webmail enabled'),
            editable        => \&_sslWebmailIsEditable,
            defaultValue    => 0,
            hiddenOnViewer  => 1,
            help            => __('Webmail and groupware platform. SSL ' .
                                  'enabled version. To enable this option ' .
                                  'you have to "Issue Certificate" first.'),
        ),
    ];

    my $customActions = [
        new EBox::Types::MultiStateAction(
            acquirer    => \&_acquireIssued,
            model       => $self,
            states => {
                issued => {
                    name => 'revoke',
                    printableValue => __('Revoke certificate'),
                    handler => \&_doRevoke,
                    message => __('Certificate revoked'),
                },
                nonissued => {
                    name => 'issue',
                    printableValue => __('Issue certificate'),
                    handler => \&_doIssue,
                    message => __('Certificate issued'),
                },
                badissued => {
                    name => 'revoke_and_issue',
                    printableValue => __('Revoke and reissue certificate'),
                    handler => \&_doRevokeAndIssue,
                    message => __('Certificate issued'),
                },
            }
        ),
    ];

    my $dataTable = {
        tableName           => 'VDomains',
        printableTableName  => __('Virtual Domains'),
        printableRowName    => __('virtual domain'),
        modelDomain         => 'OpenChange',
        defaultActions      => ['editField', 'changeView'],
        customActions       => $customActions,
        tableDescription    => $tableHead,
        help                => __('This table is summary of the attributes ' .
                                  'and access gateways associated with each ' .
                                  'virtual mail domain.'),
    };

    return $dataTable;
}

# Method: _zentyalManagedAcquirer
#
#   Checks if the domain exists in the cached DNS module DomainTable (it is
#   is managed by Zentyal) to show the value in the table.
#
sub _zentyalManagedAcquirer
{
    my ($type) = @_;

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');
    my $domain = $self->_dnsDomainInfo($vdomain);

    return (defined $domain);
}

# Method: _certificateAcquirer
#
#   Checks if the certificate for the domain is issued by the CA to show
#   the value in the table.
#
sub _certificateAcquirer
{
    my ($type) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        return 0;
    }

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    return (defined $self->certificate($vdomain));
}

# Method: _autodiscoverRecordAcquirer
#
#   Checks if the certificate for the domain is issued by the CA to show
#   the value in the table.
#
sub _autodiscoverRecordAcquirer
{
    my ($type) = @_;

    my $ret = 0;
    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    # If the domain is managed by zentyal check the DNS model
    my $domain = $self->_dnsDomainInfo($vdomain);
    if (defined $domain) {
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $hostName = $sysinfo->hostName();

        my $dns = EBox::Global->modInstance('dns');
        my $dnsDomains = $dns->model('DomainTable');
        my $dnsRowId = $domain->{rowId};
        my $dnsRow = $dnsDomains->row($dnsRowId);

        my $hostModel = $dnsRow->subModel('hostnames');
        my $hostRow = $hostModel->find(hostname => $hostName);
        if (defined $hostRow) {
            my $aliasModel = $hostRow->subModel('alias');
            my $aliasRow = $aliasModel->find(alias => 'autodiscover');
            $ret = (defined $aliasRow);
        }
    }

    return $ret;
}

# Method: _autodiscoverRecordStorer
#
#   Checks if the certificate for the domain is issued by the CA to show
#   the value in the table.
#
sub _autodiscoverRecordStorer
{
    my ($type, $hash) = @_;

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    # Add or remove the autodiscover CNAME record pointing to zentyal
    my $autodiscoverWasEnabled = _autodiscoverRecordAcquirer($type);
    my $autodiscoverEnabled = $type->value();
    if ($autodiscoverWasEnabled xor $autodiscoverEnabled) {
        $self->_setAutoDiscoverRecord($vdomain, $autodiscoverEnabled);
    }
}

# Method: _autodiscoverIsEditable
#
#   The autodiscover record can only be configured if the dns domain is
#   managed by Zentyal (as we have to add it to the domain configuration),
#   and if the certificate for the domain is in place, otherwise it won't
#   work.
#
sub _autodiscoverIsEditable
{
    my ($type) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        return 0;
    }

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');
    my $domain = $self->_dnsDomainInfo($vdomain);

    my $domainManagedByZentyal = (defined $domain);
    my $certInPlace = (defined $self->certificate($vdomain));

    return ($domainManagedByZentyal and $certInPlace);
}

# Method: _sslRpcProxyIsEditable
#
#   RPC over HTTPs can be enabled only if the certificate is in place
#
sub _sslRpcProxyIsEditable
{
    my ($type) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        return 0;
    }

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    return (defined $self->certificate($vdomain));
}

# Method: _sslWebmailIsEditable
#
#   Webmail using SSL can be enabled only if the certificate is in place
#
sub _sslWebmailIsEditable
{
    my ($type) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        return 0;
    }

    my $self = $type->model();
    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    return (defined $self->certificate($vdomain));
}

# Method: _acquireIssued
#
#   Check if the certificate is issued to show the issue or revoke custom
#   action
#
sub _acquireIssued
{
    my ($self, $id) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        return 'nonissued';
    }

    my $row = $self->row($id);
    my $vdomain = $row->printableValueByName('vdomain');
    if ($self->certificate($vdomain)) {
        return 'issued';
    }

    my $metadata = $ca->getCertificateMetadata(cn => $vdomain);
    if ($metadata and ($metadata->{state} eq 'V')) {
        # certificate exists, but with bad parameters
        return 'badissued';
    }

    return 'nonissued';
}


sub _issueCertificate
{
    my ($self, $vdomain) = @_;
    my $ca      = $self->global()->modInstance('ca');
    unless ($ca->isAvailable()) {
        throw EBox::Exceptions::External(
            __x('There is not an available Certication Authority. You must {oh}create or renew it{ch}',
                oh => "<a href='/CA/Index'>",
                ch => "</a>"));
    }

    my $sysinfo = $self->global()->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $caCert = $ca->getCACertificateMetadata();
    $ca->issueCertificate(
        commonName => $vdomain,
        endDate    => $caCert->{expiryDate},
        openchange => 1,
        subjAltNames => [
            { type  => 'DNS', value =>  "${hostname}.${vdomain}" },
            { type  => 'DNS', value => "autodiscover.${vdomain}" }
        ]
    );

    # Set openchange as changed to copy the certificate to ocsmanager folder
    # on save changes
    $self->parentModule()->setAsChanged();
    # set CA as changed, so the certificate will used by services if needed
    $ca->setAsChanged();
}

sub _revokeCertificate
{
    my ($self, $vdomain) = @_;
    my $ca = $self->global()->modInstance('ca');

    $ca->revokeCertificate(
        commonName => $vdomain,
        reason     => 'unspecified',
    );

    # Set openchange as changed to remove the certificate from ocsmanager
    # folder on save changes
    $self->parentModule()->setAsChanged();
    # no need to set CA as changed like when issue the certificate
    # because we cannot automatically reissue certificates services
}

# Method: _doIssue
#
#   Issue the certificate for the virtual domain using Zentyal CA
#
sub _doIssue
{
    my ($self, $action, $id, %params) = @_;
    my $row = $self->row($id);
    my $vdomain = $row->printableValueByName('vdomain');
    if (defined $self->certificate($vdomain)) {
        throw EBox::Exceptions::External(
            __x('Certificate for domain {x} already exists.', x => $vdomain));
    }

    $self->_issueCertificate($vdomain);
}

# Method: _doRevoke
#
#   Issue certificate for virtual domain on Zentyal CA
#
sub _doRevoke
{
    my ($self, $action, $id, %params) = @_;

    my $row = $self->row($id);
    my $vdomain = $row->printableValueByName('vdomain');

    unless (defined $self->certificate($vdomain)) {
        throw EBox::Exceptions::External(
            __x('Certificate for domain {x} does not exists.', x => $vdomain));
    }

    $self->_revokeCertificate($vdomain);
}

sub _doRevokeAndIssue
{
    my ($self, $action, $id, %params) = @_;

    my $row = $self->row($id);
    my $vdomain = $row->printableValueByName('vdomain');
    $self->_revokeCertificate($vdomain);
    $self->_issueCertificate($vdomain);
}

# Method: _setAutoDiscoverRecord
#
#   Adds the autodiscover CNAME record to the host name in the domain
#
sub _setAutoDiscoverRecord
{
    my ($self, $vdomain, $enabled) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $dns = EBox::Global->modInstance('dns');
    my $model = $dns->model('DomainTable');
    if ($enabled) {
        $model->addHostAlias($vdomain, $hostname, 'autodiscover');
    } else {
        $model->delHostAlias($vdomain, $hostname, 'autodiscover');
    }
}

# Method:
#
#   Retrieve the certificate metadata for the specified domain
#
# Returns:
#
#   The certificate metadata if the certificate is present, is valid, and has
#   the required alternative names for RPC proxy and Autodiscover,
#   undef otherwise
#
sub certificate
{
    my ($self, $vdomain) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $ca = EBox::Global->modInstance('ca');
    my $metadata =  $ca->getCertificateMetadata(cn => $vdomain);
    if (defined $metadata) {
        if ($metadata->{state} eq 'V') {
            my $rpcProxyAltName = 0;
            my $autodiscoverAltName = 0;
            foreach my $alt (@{$metadata->{subjAltNames}}) {
                if (uc ($alt->{type}) eq 'DNS') {
                    if (lc ($alt->{value}) eq "$hostname.$vdomain") {
                        $rpcProxyAltName = 1;
                    }
                    if (lc ($alt->{value}) eq "autodiscover.$vdomain") {
                        $autodiscoverAltName = 1;
                    }
                }
            }
            if ($rpcProxyAltName and $autodiscoverAltName) {
                return $metadata;
            }
        }
    }

    return undef;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $mail = EBox::Global->modInstance('mail');
    my $vdomainsModel = $mail->model('VDomains');

    my %new = map {
        $vdomainsModel->row($_)->printableValueByName('vdomain') => $_
    } @{$vdomainsModel->ids()};

    my %current = map {
        $self->row($_)->printableValueByName('vdomain') => $_
    } @{$currentRows};

    my $modified = 0;

    my @toAdd = grep { not exists $current{$_} } keys %new;
    my @toDel = grep { not exists $new{$_} } keys %current;

    foreach my $d (@toAdd) {
        $self->addRow(vdomain => $d, zentyalManaged => 0,
                      certificate => 0, autodiscoverRecord => 0);
        $modified = 1;
    }

    foreach my $d (@toDel) {
        $self->removeRow($current{$d}, 1);
        $modified = 1;
    }

    return $modified;
}

sub precondition
{
    my ($self) = @_;

    unless ($self->parentModule->isEnabled()) {
        $self->{preconditionFail} = 'notEnabled';
        return 0;
    }

    unless ($self->parentModule()->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return 0;
    }

    my $mail = EBox::Global->modInstance('mail');
    my $v = $mail->model('VDomains');
    unless (scalar (@{$v->ids()})) {
        $self->{preconditionFail} = 'novdomains';
        return 0;
    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notEnabled') {
        # no show message because provision model precondition takes care of this
        return '';
    }

    if ($self->{preconditionFail} eq 'notProvisioned') {
        # no shown message because it is already shown in the rpcproxy model
        return '';
    }

    if ($self->{preconditionFail} eq 'novdomains') {
        return __x('There are not configured {oh}virtual domains{ch}.',
                   oh => "<a href=/Mail/View/VDomains>", ch => "</a>");
    }
}

sub enableAllVDomain
{
    my ($self, $vdomain) = @_;
    if (not $self->findId(vdomain => $vdomain)) {
        EBox::warn("Cannot enable vdomain $vdomain in OpenChange because it does not exists");
        return;
    }

    # issue certificate
    $self->_issueCertificate($vdomain);
    # enable options
    my $row = $self->find(vdomain => $vdomain);
    my $rowChanged = 0;
    my @toEnable = qw(autodiscoverRecord rpcproxy_https webmail_https);
    foreach my $elementName (@toEnable) {
        my $element = $row->elementByName($elementName);
        if ($element->editable()) {
            $element->setValue(1);
            $rowChanged = 1;
        } else {
            EBox::warn("OpenChange option $elementName no editable in $vdomain. Skipping");
        }
    }
    if ($rowChanged) {
        $row->store();
    }
}

sub _cacheDnsDomains
{
    my ($self) = @_;

    my $info = {};
    my $dns = EBox::Global->modInstance('dns');
    my $dnsDomains = $dns->model('DomainTable');
    foreach my $id (@{$dnsDomains->ids()}) {
        my $dnsRow = $dnsDomains->row($id);
        my $name = $dnsRow->printableValueByName('domain');
        $info->{$name} = { rowId => $id };
    }
    $self->{dnsDomains} = $info;
}

sub _dnsDomainInfo
{
    my ($self, $vdomain) = @_;

    unless (exists $self->{dnsDomains}) {
        $self->_cacheDnsDomains();
    }

    return $self->{dnsDomains}->{$vdomain};
}

sub invalidateCache
{
    my ($self) = @_;

    delete $self->{dnsDomains};
}

# Method: anyWebmailHTTPSEnabled
#
#   Returns wether or not any domain has HTTPS webmail enabled
#
sub anyWebmailHTTPSEnabled
{
    my ($self) = @_;

    foreach my $id (@{$self->ids()}) {
        if ($self->row($id)->valueByName('webmail_https')) {
            return 1;
        }
    }

    return 0;
}

1;
