# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Order;

use strict;
use warnings;

#
# Method: new 
#
#   	Construct for EBox::Oder. This class is useful to order elements stored
#	in gconf
#
# Parameters:
#
#       module - module class which contains the gconf elements to order
#	keys - gconf directory which contais the elements to order
#
# Returns:
#
#       EBox::Order object
#
sub new # (module, key) 
{
	my $class = shift;
	my $self = {};
	$self->{mod} = shift;
	$self->{key} = shift;
	bless($self, $class);
	return $self;
}

#
# Method: mod 
#	
#	Returns the module which this class operates in
#
# Returns:
#
#	An object of the  stored class
#
sub mod
{
	my $self = shift;
	return $self->{mod};
}

#
# Method: key
#	
#	Returns the key which entries are oredered
#
# Returns:
#
#	An object of the  stored class
#
sub key
{
	my $self = shift;
	return $self->{key};
}

#
# Method: highest 
#	
#	Returns the highest ordered entry
#
# Returns:
#
#	string - contaning the highest number
#
sub highest
{
	my $self = shift;
	my $high = 0;
	my @keys = $self->mod->all_dirs($self->key);
	for (@keys) {
		my $aux = $self->mod->get_int("$_/order");
		if (($aux > $high)) {
			$high = $aux;
		}
	}
	return $high;
}

#
# Method: lowest 
#	
#	Returns the lowest ordered entry
#
# Returns:
#
#	scalar - contaning the lowest number
#
sub lowest
{
	my $self = shift;
	my $low = 0;
	my @keys = $self->mod->all_dirs($self->key);
	for (@keys) {
		my $aux = $self->mod->get_int("$_/order");
		if (($low < 1) || ($aux < $low)) {
			$low = $aux;
		}
	}
	return $low;
}

#
# Method: nextn 
#
#	Given a number of an entry it returns the next available entry
#
# Parameters:
#
#       n - entry number
#
# Returns:
#
#       scalar - containig the next entry after the given one

sub nextn # (n) 
{
	my ($self, $n) = @_;
	my $next = $self->highest;
	if ($next < 1) {
		return $n;
	}
	my @keys = $self->mod->all_dirs($self->key);
	foreach (@keys) {
		my $aux = $self->mod->get_int("$_/order");
		if (($aux > $n) && ($aux < $next)) {
			$next = $aux;
		}
	}
	return $next;
}

#
# Method: prevn 
#
#	Given a number of an entry it returns the previous available entry
#
# Parameters:
#
#       n - entry number
#
# Returns:
#
#       scalar - containing the entry before the given one
sub prevn # (n) 
{
	my ($self, $n) = @_;
	my $prev = $self->lowest;
	if ($prev < 1) {
		return $n;
	}
	my @keys = $self->mod->all_dirs($self->key);
	foreach (@keys) {
		my $aux = $self->mod->get_int("$_/order");
		if (($aux < $n) && ($aux > $prev)) {
			$prev = $aux;
		}
	}
	return $prev;
}

#
# Method: get 
#
#	Returns the given entry
#
# Parameters:
#
#       n - entry number
#
# Returns:
#
#       The entry whose number matches the given one
sub get # (n) 
{
	my ($self, $n) = @_;
	my @keys = $self->mod->all_dirs($self->key);
	foreach (@keys) {
		if ($self->mod->get_int("$_/order") eq $n) {
			return $_;
		}
	}
	return undef;
}

#
# Method: swap 
#
# 	Exchange two given entries	
#
# Parameters:
#
#       n - entry number
#	m - entry number to exchange
#
sub swap # (n, m) 
{
	my ($self, $n, $m) = @_;
	my @keys = $self->mod->all_dirs($self->key);
	foreach (@keys) {
		my $aux = $self->mod->get_int("$_/order");
		if ($aux eq $n) {
			$self->mod->set_int("$_/order", $m);
		} elsif ($aux eq $m) {
			$self->mod->set_int("$_/order", $n);
		}
	}
}

#
# Method: list 
#
# 	Returns a list of ordered entries
#
#  Returns: 
#
#	array ref - a list of ordered entries
#
sub list
{
	my $self = shift;
	my @array = ();
	my $i = $self->lowest;
	my $high = $self->highest;
	if ($i < 1) {
		return \@array;
	}

	while (1) {
		push(@array, $self->get($i));
		if ($i eq $high) {
			last
		}
		$i = $self->nextn($i);
	}
	return \@array;
}

1;
