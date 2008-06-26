# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::OpenVPN::Model::DownloadClientBundle;
use base 'EBox::Model::DataForm::Download';
#

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Types::Host;
use EBox::OpenVPN::Types::Certificate;

# XXX TODO
#   - client type must hid unavailable types
#  - certificates select must not show the certificate of the server
#   - addresses must be filled with the dafault addresses obtained from 
#    the serversAddr class method in EBox::OpenVPN::Server::ClientBundleGenerator
#   - installer option should be only availble for windows clients
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
#    my ($self) = @_;

    my @tableHead = 
        ( 

         new EBox::Types::Select(
                                 fieldName => 'clientType', 
                                 printableName => __(q{Client's type}), 
                                 editable => 1,
                                 populate => \&_clientTypeOptions,
#                                  populate => sub {
#                                      return $self->_clientTypeOptions()
#                                  },
                                ),
         new EBox::OpenVPN::Types::Certificate(
                           fieldName => 'certificate',
                           printableName => __("Client's certificate"),
#                           excluded => $self->_parentCert,
                           editable => 1,
                                ),
         new EBox::Types::Boolean(
                                  fieldName => 'installer',
                        printableName => __(q(Add OpenVPN's installer to bundle)),
                                  editable => 1,
                                 ),
         new EBox::Types::Host(
                                          fieldName => 'addr1',
                                          printableName => __('Server address'),
                                          editable => 1,
                                         ),
         new EBox::Types::Host(
                               fieldName => 'addr2',
                 printableName => __('Additional server address (optional)'),
                               editable => 1,
                               optional => 1,
                                         ),
         new EBox::Types::Host(
                               fieldName => 'addr3',
                 printableName => __('Additional server address (optional)'),
                               editable => 1,
                               optional => 1,
                                         ),
        );

    my $dataTable = 
        { 
            'tableName'               => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Download client bundle'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/DownloadClientBundle',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
             'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}




sub _clientTypeOptions
{
#     my ($self) = @_;

#     my $confRow = $self->_parentConfRow();
#     my $EBoxToEBoxTunnel = $confRow->elementByName('pullRoutes')->value();
#     my @disabledAttr = (disabled => 'disabled');

    my @options = (
                   { 
                    value => 'windows', 
                    printableValue =>'Windows', 
#                    $EBoxToEBoxTunnel ? @disabledAttr : (),
                   }, 
                   { 
                    value => 'linux',   
                    printableValue =>'Linux',
#                    $EBoxToEBoxTunnel ? @disabledAttr : (),
                   } ,
                   { 
                    value => 'EBoxToEBox', 
                    printableValue => __('EBox to EBox tunnel') ,
#                    $EBoxToEBoxTunnel ? () : @disabledAttr,
                   },
                   
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


sub _validateCertificate
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my $cert = $params_r->{certificate}->value();

    my $confRow = $self->_serverConfRow();
    my $serverCertificate = $confRow->elementByName('certificate')->value();
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
       __('Invalid client type: the server does not allow eBox-to-eBox tunnels')
                                            );
        }
        return;
    }


    if ($pullRoutes) {
            throw EBox::Exceptions::External(
       __('Invalid client type: the server is intended for eBox-to-eBox tunnels')
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
    my $certificate = $row->elementByName('certificate')->value();
    my $installer = $row->elementByName('installer')->value();    


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
                                      addresses => \@serverAddr,
                                      installer => $installer,
                                         );

    $self->pushFileToDownload($bundle);
}


sub _server
{
    my ($self) = @_;
    my $name = $self->row()->parentRow()->elementByName('name')->value();

    my $openvpn = EBox::Global->modInstance('openvpn');
    return $openvpn->server($name);
}

1;
