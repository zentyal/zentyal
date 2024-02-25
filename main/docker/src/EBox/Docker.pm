use strict;
use warnings;

package EBox::Docker;

use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Exceptions::Internal;
use EBox::Util::Init;
use TryCatch;

use constant CONFDIR => '/var/lib/zentyal/docker/';
use constant MANAGE_SCRIPT => CONFDIR . 'docker-manage.sh';
use constant POSTSERVICE_HOOK => '/etc/zentyal/hooks/firewall.postservice';

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
        name => 'docker',
        printableName => __('Docker'),
        @_
    );

    bless ($self, $class);

    return $self;
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
        url => 'Docker/View/Settings',
        text => $self->printableName(),
        separator => 'Core',
        icon      => 'docker',
        order => 1
    );

    $root->add($item);
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('Install docker and its dependencies'),
            'reason' => __('The Zentyal docker module needs some third party software to be launched.'),
            'module' => 'docker'
        },
        {
            'action' => __('Generate docker manager script'),
            'reason' => __('The Zentyal docker manager script used to handle internal management containers.'),
            'module' => 'docker'

        }
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
        return [
        {
            'file' => MANAGE_SCRIPT,
            'module' => 'docker',
            'reason' => __x('{server} configuration script', server => 'docker'),
        }
    ];
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
            name => 'docker',
            type => 'systemd'
        }
    ];
}


# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Execute initial-setup script if is first install
    my $software = $self->global()->modInstance('software');
    if (!$software->isInstalled('zentyal-docker')) {
        $self->SUPER::initialSetup($version);
    }

    if (not EBox::Sudo::fileTest('-d', CONFDIR)) {
        EBox::Sudo::root('mkdir '.CONFDIR);
    }
    # create manager script with default data
    my $settings = $self->model('Settings');
    my $persistentVolumeName = $settings->value('persistentVolumeName');
    my $containerName = $settings->value('containerName');
    my $adminPort = $settings->value('adminPort');

    my @params = (
        persistentVolumeName => $persistentVolumeName,
        containerName => $containerName,
        adminPort => $adminPort,
    );

    $self->_handleNetworkAndFirewall($adminPort);

    # Postservice hook
    my @array = [];
    $self->writeConfFile(POSTSERVICE_HOOK, 'docker/postservice.firewall.mas', \@array,
                         {'uid' => 'root', 'gid' => 'root', mode => '755'});

    $self->_writeManagerScript(@params);
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

    # create manager script
    my $settings = $self->model('Settings');
    my $persistentVolumeName = $settings->value('persistentVolumeName');
    my $containerName = $settings->value('containerName');
    my $adminPort = $settings->value('adminPort');
    my @params = (
        persistentVolumeName => $persistentVolumeName,
        containerName => $containerName,
        adminPort => $adminPort,
    );

    $self->_writeManagerScript(@params);

    # Postservice hook
    my @array = [];
    $self->writeConfFile(POSTSERVICE_HOOK, 'docker/postservice.firewall.mas', \@array,
                         {'uid' => 'root', 'gid' => 'root', mode => '755'});

    if ($self->isEnabled()) {
        $self->enforceServiceStatus();
        $self->_handleNetworkAndFirewall($adminPort);
    } else {
        $self->stopService();
    }
}

sub _writeManagerScript()
{
    my ($self, @params) = @_;

    $self->writeConfFile(
        MANAGE_SCRIPT,
        "docker/docker-manage.sh.mas",
        \@params,
        { uid => '0', gid => '0', mode => '755' }
    );
}

sub stopService
{
    my ($self) = @_;

    try {
        my $res = system(MANAGE_SCRIPT . ' stop');
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error("Something went wrong while stopping the container");
        throw EBox::Exceptions::Internal($e);
    }

    return 1;
}

sub isRunning
{
    my ($self) = @_;
    return $self->runDockerStatus();
}

sub enforceServiceStatus
{
    my ($self) = @_;

    sleep(10);

    try {
        # Check if the volumen exists, if does not, the Portainer project must be created
        my $volumenExists = $self->runCheckVolumenExists();
        if ($volumenExists != 1) {
            EBox::debug('Creating the project...');
            $self->runDockerCreate();
            return 1;
        }

        # Check if the volumen exists and the Portainer container must be created
        my $containerExists = $self->runCheckContainerExists();
        if ($volumenExists == 1 and $containerExists != 1) {
            EBox::debug('Creating the container...');
            $self->runDockerContainerCreate();
            return 1;
        }

        # Check if the Portainer container must be started
        my $checkContainer = $self->runCheckContainerIsRunning();
        if ($checkContainer != 1) {
            EBox::debug('Starting the container...');
            $self->runDockerStart();
            return 1;
        } else {
            EBox::debug('The container is already started...');
            return 1
        }
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error("Something went wrong while creating the container");
        throw EBox::Exceptions::Internal($e);
    }

    return 1;
}

sub runCheckVolumenExists
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' check_volumen');
    if($res == 256) {
        return 1;
    }

    return undef;
}

sub runCheckContainerExists
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' check_container_exists');
    if($res == 256) {
        return 1;
    }

    return undef;
}

sub runCheckContainerIsRunning
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' check_container_is_running');
    if($res == 256) {
        return 1;
    }

    return undef;
}

sub runDockerCreate
{
    my ($self) = @_;

    try {
        EBox::Sudo::root(MANAGE_SCRIPT . ' create');
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error("Something went wrong creating the volumen or the container");
        throw EBox::Exceptions::Internal($e);
    }

    return 1;
}

sub runDockerContainerCreate
{
    my ($self) = @_;

    try {
        system(MANAGE_SCRIPT . ' create_container');
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error("Something went wrong creating the container");
        throw EBox::Exceptions::Internal($e);
    }

    return 1;
}

sub runDockerStart
{
    my ($self) = @_;

    try {
        system(MANAGE_SCRIPT . ' start');
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::error("Something went wrong starting the container");
        throw EBox::Exceptions::Internal($e);
    }

    return 1;
}

sub runDockerStatus
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' check_container_is_running');

    if($res == 256) {
        return 1;
    }
    return undef;
}

sub runDockerRestart
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' restart');
    unless ($res == 256) {
        EBox::error("Something went wrong restarting the container");
        throw EBox::Exceptions::Internal("Something went wrong restarting the container");
    }

    return 1;
}

sub runDockerDestroy
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' destroy');
    if($res == 0) {
        return 1;
    }

    return undef;
}

# Constructor: isPortInUse
#
#       Check if port is used
#
# Returns:
#
#       boolean - 1, if the port is in use, undef if is free.
#
sub isPortInUse
{
    my ($self, $port) = @_;

    my $result = system("ss -tuln | grep ':$port ' >/dev/null 2>/dev/null");
    if ($result == 256) {
        return undef;
    }

    return 1;
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled) {
        # To avoid lock issues
        sleep(5);
        EBox::Util::Init::moduleRestart('firewall');
    }
}

sub _handleNetworkAndFirewall
{
    my ($self, $port) = @_;

    $self->_createNetworkServices($port);
    $self->_createFirewallRule();
}

sub _createNetworkServices
{
    my ($self, $port) = @_;

    my $services = EBox::Global->modInstance('network');
    my $serviceName = 'docker';
    if($services->serviceExists(name => $serviceName)) {
        $services->removeService(name => $serviceName)
    }

    $services->addMultipleService(
        'name' => $serviceName,
        'printableName' => 'Docker',
        'description' => __('Docker admin server'),
        'internal' => 1,
        'readOnly' => 1,
        'services' => [
            {
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => $port,
            },
        ],
    );
}

sub _createFirewallRule
{
    my $serviceName = 'docker';
    # Add rule to "Filtering rules from internal networks to Zentyal"
    my $firewall = EBox::Global->modInstance('firewall');
    $firewall->setInternalService($serviceName, 'accept');
    $firewall->saveConfigRecursive();
}

1;
