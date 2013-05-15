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

package EBox::Global;

use EBox;
use EBox::GlobalImpl;
use EBox::Exceptions::Internal;
use Devel::StackTrace;

# Methods of GlobalImpl that need to know if the instance is read-only or not
my %ro_methods = map { $_ => 1 } qw(modEnabled modChange modInstances modInstancesOfType modInstance modDepends modRevDepends edition);

# Methods of GlobalImpl that cannot be called on read-only instances
my %rw_only_methods = map { $_ => 1 } qw(modIsChanged modChange modRestarted saveAllModules revokeAllModules modifiedModules);

sub new
{
    my ($class, $ro, %args) = @_;

    my $self = {};
    $self->{'ro'} = $ro;
    $self->{'global'} = EBox::GlobalImpl->instance(%args);

    bless($self, $class);

    return $self;
}

sub isReadOnly
{
    my ($self) = @_;

    return $self->{ro};
}

sub getInstance
{
    my ($self, $ro) = @_;

    return EBox::Global->new($ro);
}

# TODO: This method should never be called directly, but
# as there are lots of call along the code, we need to wrap it
sub instance
{
    return EBox::Global->new();
}

sub AUTOLOAD
{
    my ($self, @params) = @_;

    my $methodName = our $AUTOLOAD;

    $methodName =~ s/.*:://;

    return if ($methodName eq 'DESTROY');

    unless (ref $self) {
        $self = EBox::Global->new();
    }
    my $global = $self->{'global'};

    unless ($global->can($methodName)) {
        EBox::debug((new Devel::StackTrace)->as_string());
        throw EBox::Exceptions::Internal("Undefined method EBox::GlobalImpl::$methodName");
    }

    my $ro = $self->{'ro'};
    if ($ro and $rw_only_methods{$methodName}) {
        EBox::debug((new Devel::StackTrace)->as_string());
        throw EBox::Exceptions::Internal("Cannot call $methodName method on a read-only instance");
    }

    if ($ro_methods{$methodName}) {
        $global->$methodName($ro, @params);
    } else {
        $global->$methodName(@params);
    }
}

1;
