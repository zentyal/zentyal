package EBox::Quassel;

use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

my $CONFFILE = '/tmp/FIXME.conf';

# Method: _create
#
# Overrides:
#
#       <Ebox::Module::Base::_create>
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(
        name => 'quassel',
        printableName => __('Quassel'),
        @_
    );

    bless ($self, $class);

    return $self;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'quasselcore';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addService(
                'name' => $serviceName,
                'description' => __('Quassel Core server'),
                'protocol'        => 'tcp',
                'sourcePort'      => 'any',
                'destinationPort' => 4242,
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'deny');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $item = new EBox::Menu::Item(
        url => 'Quassel/View/Settings',
        text => $self->printableName(),
        separator => 'Communications',
        order => 750
    );

    $root->add($item);
}

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my $daemons = [
        {
            name => 'quasselcore',
            type => 'init.d',
            pidfiles => ['/var/run/quasselcore.pid']
        },
    ];

    return $daemons;
}

# Method: _setConf
#
# Overrides:
#
#       <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $settings = $self->model('Settings');
    my $booleanValue = $settings->value('booleanField');
    my $textValue = $settings->value('textField');

    my @params = (
        boolean => $booleanValue,
        text => $textValue,
    );

#     $self->writeConfFile(
#         $CONFFILE,
#         "quassel/service.conf.mas",
#         \@params,
#         { uid => '0', gid => '0', mode => '644' }
#     );
}

1;
