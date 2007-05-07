# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Types::Basic;
use strict;
use warnings;

use base 'EBox::Types::Abstract';

use EBox::Exceptions::MissingArgument;

sub new
{
        my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);

	# Setting as non-optional, if no optional value is passed
	if ( not defined ( $self->optional() ) ) {
	  $self->setOptional(0);
	}

        bless($self, $class);
        return $self;
}

sub paramExist
{
	my ($self, $params, $field) = @_;

	return (defined($params->{$self->fieldName()}));

}

sub setMemValue
{
	my ($self, $params) = @_;

	if ($self->optional() == 0) {
		unless ($self->paramExist($params)) {
			throw EBox::Exceptions::MissingArgument(
						$self->printableName());
		}
	}

	$self->paramIsValid($params);

	$self->{'value'} = $params->{$self->fieldName()};
}

sub memValue
{
	my ($self) = @_;

	return $self->{'value'};
}

sub compareToHash
{
	my ($self, $hash) = @_;

	return ($self->memValue() eq $hash->{$self->fieldName()});
}

sub restoreFromHash
{
	my ($self, $hash) = @_;

	$self->{'value'} = $hash->{$self->fieldName()};
}

sub isEqualTo
{
	my ($self, $newObject) = @_;

	my $oldValue = $self->{'value'};
	my $newValue = $newObject->memValue();

	if ( not defined ( $oldValue ) or
	     not defined ( $newValue )) {
	  return 0;
	}

	return ($oldValue eq $newValue);
}

1;
