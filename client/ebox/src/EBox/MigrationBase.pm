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

1;
