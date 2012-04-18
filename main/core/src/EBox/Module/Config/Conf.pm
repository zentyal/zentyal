# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::Module::Config::Conf;

use strict;
use warnings;

use base 'EBox::Module::Config::Helper';

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
    my ($self) = @_;

    return $self->{ro};
}

sub key # (key)
{
    my ($self, $key) = @_;

    my $dir = 'ebox';
    if ($self->isReadOnly) {
        $dir = 'ebox-ro';
    }

    return $self->_key($dir, $key);
}

sub _key
{
    my ($self, $dir, $key) = @_;

    # FIXME: check performance penalty of these regexps,
    # this is executed with each redis call...

    if ($key =~ /^\//) {
        $key =~ s/\/+$//;
        unless ($key =~ /^\/$dir/) {
            throw EBox::Exceptions::Internal("Trying to use a ".
                "conf key that belongs to a different ".
                "application $key");
        }
        my $name = $self->{mod}->name;
        unless ($key =~ /^\/$dir\/modules\/$name/) {
            throw EBox::Exceptions::Internal("Trying to use a ".
                "conf key that belongs to a different ".
                "module: $key");
        }
        return $key;
    }

    my $ret = "/$dir/modules/" . $self->{mod}->name;
    if (defined($key) && $key ne '') {
        $ret .= "/$key";
    }
    return $ret;
}

1;
