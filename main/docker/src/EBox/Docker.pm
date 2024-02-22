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
use TryCatch;

use constant CONFDIR => '/var/lib/zentyal/docker/';
use constant MANAGE_SCRIPT => CONFDIR . 'docker-manage.sh';

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
        },
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

    my $services = EBox::Global->modInstance('network');
    my $serviceName = 'docker';
    unless($services->serviceExists(name => $serviceName)) {
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
                    'destinationPort' => $adminPort,
                },
            ],
        );
    }
    # Add rule to "Filtering rules from internal networks to Zentyal"
    my $firewall = EBox::Global->modInstance('firewall');
    $firewall->setInternalService($serviceName, 'accept');
    $firewall->saveConfigRecursive();

    $self->runDockerDestroy();
    $self->_writeManagerScript(@params);
    $self->enforceServiceStatus();
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

    if ($self->isEnabled()) {
        $self->enforceServiceStatus();
    } else {
        $self->runDockerStop();
    }

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
    
    $self->runDockerDestroy();
    $self->_writeManagerScript(@params);
    $self->enforceServiceStatus();
}

sub stopService
{
    my ($self) = @_;
    if ($self->isRunning() && $self->runCheckContainer()) {
        $self->runDockerStop();
    }
}

sub isRunning
{
    my ($self) = @_;
    return $self->runDockerStatus();
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

sub enforceServiceStatus
{
    my ($self) = @_;

    my $exists = $self->runCheckContainer();
    EBox::Sudo::root('systemctl restart docker');
    unless ($exists) {
        $self->runDockerCreate();
        return 1;
    }
    $self->runDockerStart();

    return 1;
}

sub runCheckContainer
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' check_project');
    if($res == 256) {
        return 1;
    }
    return undef;
}

sub runDockerStatus
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' status');
    if($res == 256) {
        return 1;
    }
    return undef;
}

sub runDockerCreate
{
    my ($self) = @_;    
    
    unless ($self->runCheckContainer()) {
        
        my $res = system(MANAGE_SCRIPT . ' create');
        if($res == 256 or $res == 0) { # TODO: Why 0? We need to review it
            return 1;
        }
        EBox::error("Something went wrong creating the container");
        throw EBox::Exceptions::Internal($res);
    }

    EBox::error("The container is already created");
    throw EBox::Exceptions::Internal("The container is already created");
}

sub runDockerStart
{
    my ($self) = @_;

    my $exists = $self->runCheckContainer();
    unless ($exists) {
        EBox::error("Triyng to start a nonexistent container");
        throw EBox::Exceptions::Internal($exists);
    }

    if($self->runDockerStatus()) {
        EBox::info("The container is already running");
        return 1;
    }

    my $res = system(MANAGE_SCRIPT . ' start');
    unless ($res == 256) {
        EBox::error("Something went wrong starting the container");
        throw EBox::Exceptions::Internal($res);
    }

    return 1;
}

sub runDockerStop
{
    my ($self) = @_;

    if(!$self->runDockerStatus()) {
        EBox::info("The container is already stopped");
        return 1;
    }

    my $res = system(MANAGE_SCRIPT . ' stop');
    unless ($res == 256 or $res == 0) { #256: already stopped, 0: stopped in that moment
        EBox::error("Something went wrong stopping the container");
        throw EBox::Exceptions::Internal($res);
    }

    return 1;
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

1;
