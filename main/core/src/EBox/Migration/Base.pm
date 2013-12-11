# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Migration::Base;
use EBox;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $confmodule = delete $opts{'confmodule'};
    my $version = delete $opts{'version'};
    my $self = { 'confmodule' => $confmodule, 'version' => $version };

    bless($self, $class);

    return $self;
}

sub _checkCurrentGConfVersion
{
	my $self = shift;

	my $currentVer = $self->{'confmodule'}->get_int("data_version");

	if (not defined($currentVer)) {
		$currentVer = 0;
	}

	$currentVer++;

	return ($currentVer eq $self->{'version'});
}

sub _setCurrentGConfVersion
{
	my $self = shift;

	$self->{'confmodule'}->set_int("data_version", $self->{'version'});
}

sub _saveGConfChanges
{
	my $self = shift;

	$self->{'confmodule'}->saveConfigRecursive();
}

sub executeGConf
{
	my $self = shift;

	my $name = $self->{'confmodule'}->name();
	my $version = $self->{'version'};
	if ($self->_checkCurrentGConfVersion()) {
		EBox::debug("Migrating $name to $version");
		$self->runGConf();
		$self->_setCurrentGConfVersion();
		$self->_saveGConfChanges();
	} else {
		EBox::debug("Skipping migration to $version in $name");
	}
}

sub execute
{
	my $self = shift;

	if (defined($self->{'confmodule'})) {
		$self->executeGConf();
	}
}

# Method: runGConf
#
#	This method must be overriden by each migration script to do
#	the neccessary changes to the data model stored in conf to migrate
#	between two consecutive versions
sub runGConf
{

}

1;
