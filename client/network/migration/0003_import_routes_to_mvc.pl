#!/usr/bin/perl

#	Migration between gconf data version 2 to 3
#
#	In version 3, static routes are now handled by MVC. So we must
#	import old gconf keys to the new scheme.
#
package EBox::Migration;

use strict;
use warnings;

use base 'EBox::MigrationBase';

# eBox uses
use EBox;
use EBox::Global;

# Constants:

# Old keys
use constant ROUTES_OLD_KEY        => 'routes';
# Model names
use constant ROUTES_MODEL_NAME     => 'StaticRoute';
# New keys
use constant ROUTE_NETWORK_KEY     => 'network';
use constant ROUTE_GATEWAY_KEY     => 'gateway';
use constant ROUTE_DESCRIPTION_KEY => 'description';

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: runGConf
#
# Overrides:
#
#      <EBox::MigrationBase::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    $self->_importStaticRoutes();

}

# Group: Private methods

# Import the static routes from old fashioned table to the new one MVC
# based
sub _importStaticRoutes
{
    my ($self) = @_;
    my $network = $self->{gconfmodule};

    my $routes = $network->array_from_dir(ROUTES_OLD_KEY);
    foreach my $route (@{$routes}) {
        my $routeId = $route->{_dir};
        my $networkIP = $route->{ip};
        my $networkMask = $route->{mask};
        my $gatewayIP = $route->{gateway};

        my $newRouteKey = ROUTES_MODEL_NAME . "/keys/$routeId";

        # FIXME? We may use autoloaded methods? But, they are quite
        #  expensive though

        # Set the new keys
        $network->set_string( "$newRouteKey/" . ROUTE_NETWORK_KEY . '_ip', $networkIP);
        $network->set_string( "$newRouteKey/" . ROUTE_NETWORK_KEY . '_mask', $networkMask);
        $network->set_string( "$newRouteKey/" . ROUTE_GATEWAY_KEY, $gatewayIP);
        # No description string is set

        # Unset old ones
        $network->delete_dir(ROUTES_OLD_KEY . "/$routeId");
    }

}

EBox::init();
my $network = EBox::Global->modInstance('network');
my $migration = new EBox::Migration(
    'gconfmodule' => $network,
    'version' => 3,
);
$migration->execute();
