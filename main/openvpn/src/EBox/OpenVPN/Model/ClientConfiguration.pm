# Copyright (C) 2008-2014 Zentyal S.L.
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

# Class: EBox::OpenVPN::Model::ClientConfiguration
#

use strict;
use warnings;

package EBox::OpenVPN::Model::ClientConfiguration;

use base 'EBox::Model::DataForm';

use TryCatch;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::MissingArgument;

use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::File;
use EBox::Types::Port;
use EBox::Types::HostIP;

use EBox::OpenVPN::Types::PortAndProtocol;
use EBox::OpenVPN::Client::ValidateCertificate;

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
    # allowDownload option is disabled until the bug with allowDownload +
    # DataForm is fixed (syntoms: undef $type->row())
    my @tableHead = (
         new EBox::Types::Host(
                               fieldName => 'server',
                               printableName => __('Server'),
                               editable => 1,
                              ),
         new EBox::OpenVPN::Types::PortAndProtocol(
                                                    fieldName => 'serverPortAndProtocol',
                                                    printableName => __('Server port'),
                                                    editable => 1,
                                                  ),
         new EBox::Types::File(
                               fieldName => 'caCertificate',
                               printableName => __("CA's certificate"),
                               editable => 1,
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
#                               allowDownload => 1,
                               user          => 'root',
                               allowUnsafeChars => 1,
                               optional => 1,
                               optionalLabel => 0,
                              ),
         new EBox::Types::File(
                               fieldName => 'certificate',
                               printableName => __("Client's certificate"),
                               editable => 1,
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
#                               allowDownload => 1,
                               user          => 'root',
                               allowUnsafeChars => 1,
                               optional => 1,
                               optionalLabel => 0,
                              ),
         new EBox::Types::File(
                               fieldName => 'certificateKey',
                               printableName => __("Client's private key"),
                               editable => 1,
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
#                               allowDownload => 1,
                               user          => 'root',
                               allowUnsafeChars => 1,
                               optional => 1,
                               optionalLabel => 0,
                              ),
         new EBox::Types::Boolean(
                 fieldName =>  'tunInterface',
                 printableName => __('TUN interface'),
                 editable => 1,
                 defaultValue => 0,
                 ),
        new EBox::Types::Password(
                                  fieldName => 'ripPasswd',
                                  printableName => __('Server tunnel password'),
                                  minLength => 6,
                                  editable => 1,
                                 ),
          new EBox::Types::Port(
                                  fieldName => 'lport',
                                  printableName => __('Bind port for client'),
                                  minLength => 6,
                                  editable => 1,
                                  optional => 1,
                                  hidden => 1,
                                 ),
         new EBox::Types::HostIP(
                 fieldName  => 'localAddr',
                 printableName => __('Bind address for client'),
                 optional => 1,
                 editable => 1,
                 hidden => 1,
                 ),
         new EBox::Types::Text(
                 fieldName  => 'routeUpCmd',
                 printableName => __('Command to execute after routes are set'),
                 optional => 1,
                 editable => 1,
                 hidden => 1,
                 ),
        );

    my $dataTable =
        {
            'tableName'               => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Client configuration'),
            'automaticRemove' => 1,
            'defaultController' => '/OpenVPN/Controller/ClientConfiguration',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('client'),
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}

sub name
{
    __PACKAGE__->nameFromClass(),
}

sub configured
{
    my ($self) = @_;

    my $row = $self->row();

    $row->valueByName('server') or return 0;
    my $serverService = $row->elementByName('serverPortAndProtocol');
    $serverService->port()      or return 0;
    $serverService->protocol()  or return 0;

    $row->elementByName('caCertificate')->exist()  or return 0;
    $row->elementByName('certificate')->exist()    or return 0;
    $row->elementByName('certificateKey')->exist() or return 0;

    $row->valueByName('ripPasswd')                 or return 0;

    return 1;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (exists $params_r->{server}) {
        EBox::OpenVPN::Client->checkServer($params_r->{server}->value());
    }

    $self->_validateNoCertParams($action, $params_r, $actual_r);
    $self->_validateCerts($action, $params_r, $actual_r);
}

sub _validateNoCertParams
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my @mandatoryParams = qw(server serverPortAndProtocol ripPasswd);
    foreach my $param (@mandatoryParams) {
        my $paramChanged = exists $params_r->{$param};
        if ( $paramChanged and $params_r->{$param}->printableValue()) {
            next;
        }
        elsif ((not $paramChanged) and (exists $actual_r->{$param}) ) {
            if ($actual_r->{$param}->printableValue()) {
                next;
            }
        }

        my $printableName = $actual_r->{$param}->printableName();
        throw EBox::Exceptions::MissingArgument($printableName);
    }

}

sub _validateCerts
{
    my ($self, $action, $params_r, $all_r) = @_;
    my %path;
    my $noChanges = 1;

    my @fieldNames = qw(caCertificate certificate certificateKey);
    foreach my $fieldName (@fieldNames) {
        my $certPath;
        if ((exists $params_r->{$fieldName})) {
            $noChanges = 0;
            $certPath =  $params_r->{$fieldName}->tmpPath();
        } else {
            my $file =  $all_r->{$fieldName};
            if ($file->exist())  {
                $certPath = $file->path();
            } else {
                throw EBox::Exceptions::External(
                        __x(
                            'No file supplied or already set for {f}',
                            f => $file->printableName
                           )
                       );
            }

        }
        $path{$fieldName} = $certPath;
    }

    return if ($noChanges);

    try {
        EBox::OpenVPN::Client::ValidateCertificate::check(
            $path{caCertificate},
            $path{certificate},
            $path{certificateKey}
        );
    } catch (EBox::Exceptions::Sudo::Command $e) {
        my $cmd = $e->cmd();
        my $fieldName;
        if ($cmd =~ m/caCertificate/) {
            $fieldName = 'caCertificate';
        } elsif ($cmd =~ m/certificateKey/) {
            $fieldName = 'certificateKey';
        } else {
            $fieldName = 'cetificate';
        }
        my $type = $self->fieldHeader($fieldName);
        throw EBox::Exceptions::External(
            __x('The uploaded certificates and/or private key are not valid. File: {file}, Error: {err}',
                file => $type->printableName(), err => join (' ', @{$e->error()}))
        );
    }
}

sub _privateFilePath
{
    my ($file) = @_;

    return unless (defined($file));
    return unless (defined($file->model()));

    my $row     = $file->model()->row();
    return unless defined $row;

    my $clientName = __PACKAGE__->_clientName($row);
    $clientName or
        return;

    my $dir      = EBox::OpenVPN::Client->privateDirForName($clientName);
    my $fileName = $file->fieldName();

    return "$dir/$fileName";
}

sub formSubmitted
{
    my ($self, $row) = @_;

    # The interface type resides in the ServerModels so we must set it in the
    # parentRow
    my $toSet = $row->valueByName('tunInterface') ? 'tun' : 'tap';
    my $parentRow = $self->parentRow();
    my $ifaceType = $parentRow->elementByName('interfaceType');
    if ($ifaceType->value() ne $toSet) {
        $ifaceType->setValue($toSet);
        $parentRow->store();
    }
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

sub _clientName
{
    my ($package, $row) = @_;

    my $parent  = $row->parentRow();

    $parent or
        return undef;

    return $parent->elementByName('name')->value();
}

1;
