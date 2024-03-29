package EBox::UCP;

use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

my $UCPCONFFILE = '/etc/zentyal/ucp.conf';

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
        name => 'ucp',
        printableName => __('UCP'),
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

    return if $self->global()->communityEdition();

    my $item = new EBox::Menu::Item(
        'text' => __('UCP'),
        'icon' => 'register',
        'url' => 'UCP/View/Settings',
        'separator' => 'Core',
        'order' => 999
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
            name => 'zentyal.ucp.service',
            type => 'systemd',
            precondition => \&issetConf,
        },
    ];

    return $daemons;
}

# Method: _daemonsToDisable
#
# Overrides:
#
#   <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [ 
        {
            'name' => 'zentyal.ucp.service',
            'type' => 'systemd'
        },
    ];
}

# Method: issetConf
#
#   Check if required data exists
#
# Returns:
#
#    bool
sub issetConf
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    my $email = $settings->value('email');
    my $password = $settings->value('password');
    my $apiId = $settings->value('apiId');
    my $apiKey = $settings->value('apiKey');

    if (defined($email) && defined($password) && defined($apiId) && defined($apiKey)) {
        EBox::Sudo::root("/usr/share/zentyal-ucp/10_login.sh");
        if($? == 1) {
            return undef;
        } else {
            return 1;
        }
    } else {
        return undef;
    }
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
    my $email = $settings->value('email');
    my $password = $settings->value('password');
    my $apiId = $settings->value('apiId');
    my $apiKey = $settings->value('apiKey');

    my @params = (
        destination => 'https://ucp.zentyal.com',
    );

    $self->writeConfFile(
        $UCPCONFFILE,
        "ucp/service.conf.mas",
        \@params,
        { uid => '0', gid => '0', mode => '644' }
    );
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [{
        'action' => __('Overwrite UCP client setup'),
        'reason' => __('UCP uses a two factor auth system that needs to do a few operations.'),
        'module' => 'ucp'
    }];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('network');
        my $fw = EBox::Global->modInstance('firewall');

        my $serviceName = 'ucp';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'UCP',
                'description' => __('Unified Control Platform'),
                'readOnly' => 1,
                'services' => [ { protocol => 'tcp',
                                  sourcePort => 'any',
                                  destinationPort => 8443 } ] );

            $fw->setInternalService($serviceName, 'accept');
        }

        $fw->saveConfigRecursive();
        $self->saveConfigRecursive();

        # Execute initial-setup script
        $self->SUPER::initialSetup($version);
    }
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [{
        'file' => $UCPCONFFILE,
        'module' => 'ucp',
        'reason' => __('UCP configuration file')
    }];
}

1;
