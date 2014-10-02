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
#   TODO list:
#   - Show a link to the SOGo webmail for each virtual domain
#   - Help strings (Mateo)
#

package EBox::OpenChange::Model::VDomains;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::MultiStateAction;
use EBox::Types::Link;
use EBox::Exceptions::Internal;

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
            help            => __('FIXME'), # FIXME DOC
        ),
        new EBox::Types::Boolean(
            fieldName       => 'rpcproxy_http',
            printableName   => __('HTTP access without SSL'),
            editable        => 1,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas',
            help            => __('FIXME'), # FIXME DOC
        ),
        new EBox::Types::Boolean(
            fieldName       => 'rpcproxy_https',
            printableName   => __('HTTPS access with SSL'),
            editable        => \&_sslRpcProxyIsEditable,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/booleanViewer.mas',
            help            => __('FIXME'), # FIXME DOC
        ),
        new EBox::Types::Boolean(
            fieldName       => 'webmail_http',
            printableName   => __('HTTP Webmail enabled'),
            editable        => 1,
            defaultValue    => 0,
            HTMLViewer      => '/openchange/ajax/viewer/webmailViewer.mas',
            help            => __('FIXME'), # FIXME DOC
        ),
        new EBox::Types::Boolean(
            fieldName       => 'webmail_https',
            printableName   => __('HTTPS webmail enabled'),
            editable        => \&_sslWebmailIsEditable,
            defaultValue    => 0,
            hiddenOnViewer  => 1,
            help            => __('FIXME'), # FIXME DOC
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
        help                => __('Fixme'), # FIXME
    };

    return $dataTable;
}

# Method: _zentyalManagedAcquirer
#
#   Checks if the domain exists in the DNS module DomainTable (it is
#   is managed by Zentyal) to show the value in the table.
#
sub _zentyalManagedAcquirer
{
    my ($type) = @_;

    my $row = $type->row();
    my $vdomain = $row->printableValueByName('vdomain');

    my $dns = EBox::Global->modInstance('dns');
    my $dnsDomains = $dns->model('DomainTable');
    my $dnsRow = $dnsDomains->find(domain => $vdomain);

    return (defined $dnsRow);
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
    my $dns = EBox::Global->modInstance('dns');
    my $dnsDomains = $dns->model('DomainTable');
    my $dnsRow = $dnsDomains->find(domain => $vdomain);
    if (defined $dnsRow) {
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $hostName = $sysinfo->hostName();

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

    my $dns = EBox::Global->modInstance('dns');
    my $dnsDomains = $dns->model('DomainTable');
    my $dnsRow = $dnsDomains->find(domain => $vdomain);

    my $domainManagedByZentyal = (defined $dnsRow);
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
    return (defined $self->certificate($vdomain) ? 'issued' : 'nonissued');
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

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $caCert = $ca->getCACertificateMetadata();
    $ca->issueCertificate(
        commonName => $vdomain,
        endDate    => $caCert->{expiryDate},
        subjAltNames => [
            { type  => 'DNS', value =>  "${hostname}.${vdomain}" },
            { type  => 'DNS', value => "autodiscover.${vdomain}" }
        ]
    );

    # Set openchange as changed to copy the certificate to ocsmanager folder
    # on save changes
    $self->parentModule()->setAsChanged();
}

# Method: _doRevoke
#
#   Issue certificate for virtual domain on Zentyal CA
#
sub _doRevoke
{
    my ($self, $action, $id, %params) = @_;

    my $ca = EBox::Global->modInstance('ca');
    unless ($ca->isAvailable()) {
        throw EBox::Exceptions::External(
            __x('There is not an available Certication Authority. You must {oh}create or renew it{ch}',
                oh => "<a href='/CA/Index'>",
                ch => "</a>"));
    }

    my $row = $self->row($id);
    my $vdomain = $row->printableValueByName('vdomain');

    unless (defined $self->certificate($vdomain)) {
        throw EBox::Exceptions::External(
            __x('Certificate for domain {x} does not exists.', x => $vdomain));
    }

    my $ca = EBox::Global->modInstance('ca');
    $ca->revokeCertificate(
        commonName => $vdomain,
        reason => 'unspecified',
    );

    # Set openchange as changed to remove the certificate from ocsmanager
    # folder on save changes
    $self->parentModule()->setAsChanged();
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

    if ($self->{preconditionFail} eq 'novdomains') {
        return __x('There are not configured {oh}virtual domains{ch}.',
                   oh => "<a href=/Mail/View/VDomains>", ch => "</a>");
    }
}

1;
