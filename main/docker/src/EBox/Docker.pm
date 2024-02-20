use strict;
use warnings;

package EBox::Docker;

use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Exceptions::External;
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
    $self->_writeManagerScript(@params);
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

    my $check_project = $self->runCheckContainer();

    if ($check_project) {
        $self->runDockerStart();
    } else {
        $self->runDockerCreate();
    }
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

    my $res = system(MANAGE_SCRIPT . ' create');
    if($res == 256) {
        return 1;
    }
    return undef;
}

sub runDockerStart
{
    my ($self) = @_;
    my $res = system(MANAGE_SCRIPT . ' start');

    if($res == 256) {
        return 1;
    }
    return undef;

}

sub runDockerStop
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' stop');
    if($res == 256) {
        return 1;
    }
    return undef;
}

sub runDockerRestart
{
    my ($self) = @_;

    my $res = system(MANAGE_SCRIPT . ' restart');
    if($res == 256) {
        return 1;
    }
    return undef;
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
