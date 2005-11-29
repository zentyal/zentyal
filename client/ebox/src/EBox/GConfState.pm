# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::GConfState;

use strict;
use warnings;

use base 'EBox::GConfHelper';

use EBox::Gettext;
use EBox::Exceptions::Internal;

sub new 
{
	my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return $self;
}

sub isReadOnly
{
	my $self = shift;
	return $self->{ro};
}

sub key # (key) 
{
	my ($self, $key) = @_;

	if ($key =~ /^\//) {
		$key =~ s/\/+$//;
		unless ($key =~ /^\/ebox/) {
			throw EBox::Exceptions::Internal("Trying to use a ".
				"gconf key that belongs to a different ".
				"application $key");
		}
		my $name = $self->{mod}->name;
		unless ($key =~ /^\/ebox\/state\/$name/) {
			throw EBox::Exceptions::Internal("Trying to use a ".
				"gconf key that belongs to a different ".
				"module: $key");
		}
		return $key;
	}

	my $ret = "/ebox/state/" . $self->{mod}->name;
	if (defined($key) && $key ne '') {
		$ret .= "/$key";
	}
	return $ret;
}

1;
