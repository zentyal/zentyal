package EBox::Docker::Model::Settings;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;

use EBox::Types::Text;
use EBox::Types::Port;
use EBox::Exceptions::External;

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @fields = (
        new EBox::Types::Text(
            fieldName => 'persistentVolumeName',
            printableName => __('Persistent volume name'),
            editable => 1,
            unique => 1,
            size => '16',
            help => __('Type the name of your volume'),
            defaultValue => 'vol-portainer_data',
        ),
        new EBox::Types::Text(
            fieldName => 'containerName',
            printableName => __('Container name'),
            editable => 1,
            size => '16',
            help => __('Type the name of your container.'),
            defaultValue => 'portainer',
        ),
        new EBox::Types::Port(
            fieldName => 'adminPort',
            printableName => __("Administration port"),
            editable => 1,
            defaultValue => 9443,
        ),
    );

    my $dataTable =
    {
        tableName => 'Settings',
        printableTableName => __('Settings'),
        pageTitle => $self->parentModule()->printableName(),
        defaultActions => [ 'editField' ],
        modelDomain => 'Docker',
        tableDescription => \@fields,
        help => __('Use this form to setup the docker console'),
    };

    return $dataTable;
}

sub permanentMessage
{
    my ($self) = @_;

    my $fqdn = $self->parentModule()->global()->modInstance('sysinfo')->fqdn();
    my $port = $self->value('adminPort');
    if(!$fqdn) {
        return undef;
    }

    return __x(
        'To manage your docker setup you just need to acces to the console '
        . 'clicking on this link '
        . '{openhref}Portainer®{closehref} to do so',
        openhref  => qq{<a href="http://$fqdn:$port" target="_blank">},
        closehref => qq{</a>}
    );
}

sub permanentMessageType
{
    return 'note';
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless defined ($changedFields->{adminPort});

    my $port = $changedFields->{adminPort}->value();    
    my $docker = $self->parentModule();
    my $isPortInUse = $docker->isPortInUse($port);

    if($isPortInUse eq 1) {
        throw EBox::Exceptions::External(
            __x(
                'Port {port} is already in use', 
                port => $port
            )
        );
    }
}

1;
