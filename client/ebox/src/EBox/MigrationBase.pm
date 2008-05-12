package EBox::MigrationBase;
use strict;
use warnings;
use EBox;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $gconfmodule = delete $opts{'gconfmodule'};
    my $version = delete $opts{'version'};
    my $self = { 'gconfmodule' => $gconfmodule, 'version' => $version };

    bless($self, $class);

    return $self;
}

sub _checkCurrentGConfVersion
{
	my $self = shift;

	my $currentVer = $self->{'gconfmodule'}->get_int("data_version");


	if (not defined($currentVer)) {
		$currentVer = 0;
	}

	$currentVer++;

	return ($currentVer eq $self->{'version'});
}

sub _setCurrentGConfVersion
{
	my $self = shift;

	$self->{'gconfmodule'}->set_int("data_version", $self->{'version'});
}

sub _saveGConfChanges
{
	my $self = shift;

	$self->{'gconfmodule'}->saveConfigRecursive();
}

sub executeGConf 
{
	my $self = shift;

	my $name = $self->{'gconfmodule'}->name();
	my $version = $self->{'version'};
	if ($self->_checkCurrentGConfVersion()) {
		EBox::debug("Migrating $name to $version");
		$self->runGConf();
		$self->_setCurrentGConfVersion();
		$self->_saveGConfChanges();
	} else {
		EBox::debug("Skipping migration to $version  in $name");
	}
}

sub execute
{
	my $self = shift;

	if (defined($self->{'gconfmodule'})) {
		$self->executeGConf();
	}
}

# Method: runGConf
#
#	This method must be overriden by each migration script to do
#	the neccessary changes to the data model stored in gconf to migrate
#	between two consecutive versions
sub runGConf
{

}


# Method: addInternalService
#
#  Helper method to add new internal services to the service module and related
#  firewall rules
#
#
#  Named Parameters:
#    name - name of the service
#    protocol - protocol used by the service
#    sourcePort - source port used by the service (default : any)
#    destinationPort - destination port used by the service (default : any)
#    target - target for the firewall rule (default: allow)
sub addInternalService
{
    my ($self, %params) = @_;
    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');

    $self->_addService(%params);

    my @fwRuleParams = ($params{name});
    push @fwRuleParams, $params{target} if exists $params{target};
    $self->fwRuleForInternalService(@fwRuleParams);
}

sub fwRuleForInternalService
{
    my ($self, $service, $target) = @_;
    $service or
        throw EBox::Exceptions::MissingArgument('service');
    $target or
        $target = 'accept';

    my $fw = EBox::Global->modInstance('firewall');
    $fw->setInternalService($service, $target);
    $fw->saveConfigRecursive();
}

sub _addService
{
    my ($self, %params) = @_;
    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{protocol} or
        throw EBox::Exceptions::MissingArgument('protocol');
    exists $params{protocol} or
        throw EBox::Exceptions::MissingArgument('translationDomain');
    exists $params{sourcePort} or
        $params{sourcePort} = 'any';
    exists $params{destinationPort} or
        $params{destinationPort} = 'any';
   
    my $serviceMod = EBox::Global->modInstance('services');

    if (not $serviceMod->serviceExists('name' => $params{name})) {
        $serviceMod->addService('name' => $params{name},
                'protocol' => $params{protocol},
                'sourcePort' => $params{sourcePort},
                'destinationPort' => $params{destinationPort},
                'translationDomain' => $params{translationDomain},
                'internal' => 1,
                'readOnly' => 1
                );

    } else {
        $serviceMod->setService('name' => $params{name},
                'protocol' => $params{protocol},
                'sourcePort' => $params{sourcePort},
                'destinationPort' => $params{destinationPort},
                'translationDomain' => $params{translationDomain},
                'internal' => 1,
                'readOnly' => 1);

        EBox::info(
            "Not adding $params{name} service as it already exists instead");
    }

    $serviceMod->saveConfig();
}

1;
