# Copyright (C) 2007 Warp Networks S.L.
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

# Class:
# 
#

#   
package EBox::OpenVPN::Model::ClientConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use Error qw(:try);

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;


use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::File;

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
    my @tableHead = 
        ( 
         new EBox::Types::File(
                               fieldName => 'configurationBundle',
                               printableName => 
                                  __(q{Upload configuration's bundle}),
                               editable => 1,        
                               dynamicPath => \&_bundlePath,
#                               showFileWhenEditing => 1,
#                               allowDownload => 1,
                               optional => 1,
                              ),
         new EBox::Types::Host(
                               fieldName => 'server',
                               printableName => __('Server'),
                               editable => 1,
                               optional => 1,
                              ),
         new EBox::OpenVPN::Types::PortAndProtocol(
                                                    
                                                    fieldName => 'serverPortAndProtocol',
                                                    printableName => __('Server port'),
                                                    editable => 1,
                                                    optional => 1,

                                                   ),
         new EBox::Types::File(
                               fieldName => 'caCertificate',
                               printableName => __("CA's certificate"),
                               editable => 1,      
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
                               allowDownload => 1,
                               user          => 'root',
                               optional => 1,
                              ),
         new EBox::Types::File(
                               fieldName => 'certificate',
                               printableName => __("Client's certificate"),
                               editable => 1,                   
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
                               allowDownload => 1,
                               user          => 'root',
                               optional => 1,
                              ),
         new EBox::Types::File(
                               fieldName => 'certificateKey',
                               printableName => __("Client's private key"),
                               editable => 1,        
                               dynamicPath => \&_privateFilePath,
                               showFileWhenEditing => 1,
                               allowDownload => 1,
                               user          => 'root',
                               optional => 1,
                              ),
        new EBox::Types::Password(
                                  fieldName => 'ripPasswd', 
                                  printableName => __('Server tunnel password'), 
                                  minLength => 6,
                                  editable => 1,
                                  optional => 1,
                                 ), 

        );

    my $dataTable = 
        { 
            'tableName'               => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Client configuration'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/ClientConfiguration',
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

    $self->server()                                or return 0;
    $self->serverPortAndProtocolType()->port()     or return 0;
    $self->serverPortAndProtocolType()->protocol() or return 0;

    $self->caCertificateType()->exist()            or return 0;
    $self->certificateType()->exist()              or return 0;
    $self->certificateKeyType()->exist()           or return 0;

    $self->ripPasswd()                             or return 0;

    return 1;
}






sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;


    if (exists $params_r->{configurationBundle}) {
        if (not $params_r->{configurationBundle}->toRemove()) {
            # other parameters would be ignored
            return;
        }
    }
    
    $self->_validateManualParams($action, $params_r, $actual_r);
    $self->_validateCerts($action, $params_r, $actual_r);
}


sub _validateManualParams
{
    my ($self, $action, $params_r, $actual_r) = @_;
    my @mandatoryParams = qw( server serverPortAndProtocol ripPasswd);
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
    my ($self, $action, $params_r, $actual_r) = @_;

    my %path;

    my $noChanges = 1;
    my @fieldNames = qw(caCertificate certificate certificateKey);
    foreach my $fieldName (@fieldNames) {
        my $certPath; 
        if ( exists $params_r->{$fieldName} ) {
            $noChanges = 0;
            $certPath =  $params_r->{$fieldName}->tmpPath();
        }
        else {
            my $file =  $actual_r->{$fieldName};
            if (not $file->exist()) {
                throw EBox::Exceptions::External(
                   __x(
                       'No file supplied or already setted for {f}',
                       f => $file->printableName
                      )
                                                );
            }

            $certPath = $file->path();
        }


        $path{$fieldName} = $certPath;
    }


    return if $noChanges;


    EBox::OpenVPN::Client::ValidateCertificate::check(
                                                      $path{caCertificate},
                                                      $path{certificate},
                                                      $path{certificateKey}
                                                     );
}


sub _privateFilePath
{
    my ($file) = @_;

    return unless (defined($file));
    return unless (defined($file->model()));

    my $row     = $file->row();
    return unless defined $row;

    my $clientName = __PACKAGE__->_clientName($row);
    $clientName or
        return;
  
    my $dir      = EBox::OpenVPN::Client->privateDirForName($clientName);
    my $fileName = $file->fieldName();

    return "$dir/$fileName";
}



sub _bundlePath
{
    my ($file) = @_;

    return unless (defined($file));
    return unless (defined($file->model()));

    my $row     = $file->row();
    return unless defined $row;

    my $clientName = __PACKAGE__->_clientName($row);
    $clientName or
        return;

    return EBox::Config::tmp() . "$clientName.bundle";
}


sub addedRowNotify
{
    my ($self, $row) = @_;
    
    die 'ADDED';
    
    $self->updatedRowNotify($row);

}

sub updatedRowNotify
{
    my ($self, $row) = @_;


   my $bundleField  = $row->elementByName('configurationBundle');
    $bundleField or 
        return;

    my $bundle = $bundleField->path();
    ( -r $bundle) or
          return;

    my $clientName = __PACKAGE__->_clientName($row);
    $clientName or
        return;

    my $openvpn = EBox::Global->modInstance('openvpn');
    try {
        $openvpn->setClientConfFromBundle($clientName, $bundle);
    }
    finally {
        if (-f $bundle) {
            unlink $bundle;
        }
    };

}


 sub formSubmitted
 {
     my ($self, $row) = @_;
     die 'SUBMITTED';

}

# sub formSubmitted
# {
#     my ($self, $row) = @_;


#     my $bundleField  = $row->elementByName('configurationBundle');
#     $bundleField or 
#         return;

#     my $bundle = $bundleField->value();
#     ( -r $bundle) or
#           return;

#     my $clientName = __PACKAGE__->_clientName($row);
#     $clientName or
#         return;

#     my $openvpn = EBox::Global->modInstance('openvpn');
#     try {
#         $openvpn->setClientConfFromBundle($clientName, $bundle);
#     }
#     finally {
#         if (-f $bundle) {
#             unlink $bundle;
#         }
#     };
# }


sub _clientName
{
    my ($package, $row) = @_;

    my $parent  = $row->parentRow();

    $parent or
        return undef;

    return $parent->elementByName('name')->value();
}

1;
