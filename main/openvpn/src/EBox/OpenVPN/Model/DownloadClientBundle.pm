# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty o
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::OpenVPN::Model::DownloadClientBundle;

use base 'EBox::Model::DataForm::Download';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Types::Host;
use EBox::OpenVPN::Types::Certificate;

use TryCatch;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead =
        (

         new EBox::Types::Select(
             fieldName => 'clientType',
             printableName => __(q{Client's type}),
             editable => 1,
             populate => sub {
                                return $self->_clientTypeOptions,
                             }
             ),
         new EBox::OpenVPN::Types::Certificate(
             fieldName => 'certificate',
             printableName => __("Client's certificate"),
             excludeCertificateSub => sub { return $self->_parentCert() },
             editable => 1,
             ),
         new EBox::Types::Boolean(
             fieldName => 'installer',
             printableName => __(q(Add OpenVPN's installer to bundle)),
             editable => 1,
             help => __('OpenVPN installer for Microsoft Windows'),
             ),
         new EBox::Types::Select(
             fieldName => 'connStrategy',
             printableName => __(q{Connection strategy}),
             editable => 1,
             populate => \&_connStrategyOptions,
             ),
         new EBox::Types::Host(
                 fieldName => 'addr1',
                 printableName => __('Server address'),
                 editable => 1,
                 help => __('This is the address that will be used by your ' .
                            'clients to connect to the server. Typically, ' .
                            'this will be a public IP or host name'),
                 ),
         new EBox::Types::Host(
                 fieldName => 'addr2',
                 printableName => __('Additional server address (optional)'),
                 editable => 1,
                 optional => 1,
                 ),
         new EBox::Types::Host(
                 fieldName => 'addr3',
                 printableName => __('Second additional server address (optional)'),
                 editable => 1,
                 optional => 1,
                 ),
         );

    my $dataTable =
    {
        'tableName'               => __PACKAGE__->nameFromClass(),
        'printableTableName' => __('Download Client Bundle'),
        'printableActionName' => __('Download'),
        'automaticRemove' => 1,
        'defaultController' => '/OpenVPN/Controller/DownloadClientBundle',
        'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'modelDomain' => 'OpenVPN',
        'help'  => _help(),
    };

    return $dataTable;
}

sub _connStrategyOptions
{
    return [
        { value => 'random', printableValue => __('Random')},
        { value => 'failover', printableValue => __('Failover')},
       ];
}

sub _clientTypeOptions
{
    my ($self) = @_;

    my $confRow = $self->_serverConfRow();
    my $EBoxToEBoxTunnel = $confRow->elementByName('pullRoutes')->value();

    if ($EBoxToEBoxTunnel) {
        my $tunnelOption = {
            value => 'EBoxToEBox',
            printableValue => __('Zentyal to Zentyal tunnel') ,
        };
        return [$tunnelOption];

    }

    my @options = (
                   {
                    value => 'windows',
                    printableValue => 'Windows',
                   },
                   {
                    value => 'linux',
                    printableValue => 'Linux',
                   } ,
                   {
                    value => 'mac',
                    printableValue => 'Mac OS X',
                   } ,
                  );
    return \@options;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    $self->_validateServer($action, $params_r, $actual_r);
    $self->_validateCertificate($action, $params_r, $actual_r);
    $self->_validateClientType($action, $params_r, $actual_r);
    $self->_validateInstaller($action, $params_r, $actual_r);
}

sub _validateServer
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $configuration = $self->row()->parentRow()->subModel('configuration');

    if ((not defined $configuration) or (not $configuration->configured())) {
        throw EBox::Exceptions::External(
                                         __('Cannot make a bundle because the server  is not fully configured; please edit the configuration and retry')
                                            )
        }
}

sub _parentCert
{
    my ($self) = @_;
    my $confRow = $self->_serverConfRow();
    my $serverCertificate = $confRow->elementByName('certificate')->value();
    return $serverCertificate;
}

sub _validateCertificate
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my $cert = $params_r->{certificate}->value();
    my $serverCertificate = $self->_parentCert();

    if ($cert eq $serverCertificate) {
        throw EBox::Exceptions::External(
            __(q{Cannot use for the bundle the server's certificate})
                                        );
    }
}

sub _validateClientType
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my $clientType = $params_r->{clientType}->value();

    my $confRow = $self->_serverConfRow();
    my $pullRoutes = $confRow->elementByName('pullRoutes')->value();

    if ($clientType eq 'EBoxToEBox') {
        if (not $pullRoutes) {
            throw EBox::Exceptions::External(
       __('Invalid client type: the server does not allow Zentyal-to-Zentyal tunnels')
                                            );
        }
        return;
    }

    if ($pullRoutes) {
            throw EBox::Exceptions::External(
       __('Invalid client type: the server is intended for Zentyal-to-Zentyal tunnels')
                                            );
    }

}

sub _serverConfRow
{
    my ($self) = @_;
    my $configuration = $self->row()->parentRow()->elementByName('configuration');
    my $confRow = $configuration->foreignModelInstance()->row();
    return $confRow;
}

sub _validateInstaller
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my $installer = $params_r->{installer}->value();
    if (not $installer) {
        # nothing to verify..
        return;
    }

    my $clientType = $params_r->{clientType}->value();
    if ($clientType ne 'windows') {
        throw EBox::Exceptions::External(
          __('Installer is only available for Windows clients')
                                        );
    }
}

sub formSubmitted
{
    my ($self, $row) =  @_;

    my $type = $row->elementByName('clientType')->value();
    my $certificateElement = $row->elementByName('certificate');
    my $certificate = $certificateElement->value();
    my $installer = $row->elementByName('installer')->value();
    my $connStrategy = $row->elementByName('connStrategy')->value();

    my @serverAddr;
    foreach my $field (qw(addr1 addr2 addr3)) {
        my $addr = $row->elementByName($field)->value();
        $addr or
            next;

        push @serverAddr, $addr;
    }

    my $server = $self->_server();
    my $bundle= $server->clientBundle(
                                      clientType => $type,
                                      clientCertificate => $certificate,
                                      connStrategy => $connStrategy,
                                      addresses => \@serverAddr,
                                      installer => $installer,
                                         );

    $self->pushFileToDownload($bundle);

    $self->global()->modInstance('audit')->logAction(
                                 $self->parentModule()->name(),
                                 'Client bundle',
                                 'Download',
                                 $server->name() . ' / ' . $certificateElement->printableValue()
                                );
}

sub _server
{
    my ($self) = @_;
    my $name = $self->row()->parentRow()->elementByName('name')->value();

    my $openvpn = EBox::Global->modInstance('openvpn');
    return $openvpn->server($name);
}

sub _help
{
    return __('A client bundle is a file which contains a ready to use ' .
              'configuration for your clients');
}

# Method: precondition
#
#   Overrides <EBox::Model::DataTable::precondition> to check if the server is
#   properly configured if it is not we could not download any bundle file
#   Also check that we have created
#
# Returns:
#
#       Boolean - true if the precondition is accomplished, false
#       otherwise
sub precondition
{
    my ($self) = @_;

    my $addPreconditionMsg;
    my $configured = 0;
    try {
        my $configuration = $self->row()->parentRow()->subModel('configuration');
        if ($configuration) {
            $configured = $configuration->configured();
        } else {
            $configured = 0;
        }
    } catch ($e) {
        $addPreconditionMsg = "$e";
        $configured = 0;
    }

    if (not $configured) {
        my $msg = '<p>' . __('Cannot make a bundle because the server  is not fully configured; please complete the configuration and retry') . '<p/>';
        if ($addPreconditionMsg) {
            $msg .= '<p>' . $addPreconditionMsg . '<p/>';
        }
        $self->{preconditionFailMsg} = $msg;
        return 0;
    }

    my @certs = @{ $self->parentModule()->availableCertificates() };
    if (@certs <= 1) {
        $self->{preconditionFailMsg} = __x('There are not certificates available for this client. Please, {ohref}create one{chref}',
                                           ohref => '<a href="/CA/Index">',
                                           chref => '</a>'
                                          );
        return 0;
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Overrides <EBox::Model::DataTable::preconditionFailMsg
#
# Returns:
#
#       String - the i18ned message to inform user why this model
#       cannot be handled
#
#
sub preconditionFailMsg
{
    my ($self) = @_;
    return $self->{preconditionFailMsg};
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;


    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('name');
}

sub viewCustomizer
{
    my ($self) = @_;

    my @additionalAddresses = qw(addr2 addr3);
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
           {
              clientType => {
                  windows =>    { show => \@additionalAddresses,enable => ['installer'] },
                  linux   =>    { show => \@additionalAddresses, disable => ['installer']},
                  mac     =>    { show=> \@additionalAddresses, disable => ['installer']},
                  EBoxToEBox => { hide => \@additionalAddresses, disable => ['installer', 'connStrategy' ]},
                 }
           }  );
    return $customizer;
}

sub auditable
{
    return 0;
}

1;
