# Copyright (C) 2013 Zentyal S.L.
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

# class: EBox::Test::LDAPClass
#
#  This class is intended to use as base, replacing Test:Class and EBox::Test::Class, to build LDAP's test classes
#
package EBox::Test::LDAPClass;
use base 'EBox::Test::Class';

use EBox::Exceptions::NotImplemented;
use EBox::Ldap;

use TryCatch;
use Test::More;
use Test::Net::LDAP::Util qw(ldap_mockify);

sub class
{
    my ($class) = @_;

    throw EBox::Exceptions::NotImplemented('class', ref $class);
}

# Method: _testStubsSetFiles
#
#   Initialises some status files required to test LDAP based code.
#
sub _testStubsSetFiles
{
    # Created the ldap password files with dummy content
    my $confDir = EBox::Config::conf();
    system ("echo Foo > $confDir/ldap.passwd");
    system ("echo Foo > $confDir/ldap_ro.passwd");
}

sub _ldapInstance
{
    return EBox::Ldap->instance();
}

sub _testStubsForLDAP : Test(startup)
{
    my ($self) = @_;
    my $class = $self->class;
    eval "use $class";
    die $@ if $@;

    $self->_testStubsSetFiles();

    # Create the LDAP Mock object.
    my $ldapInstance = $self->_ldapInstance();
    $ldapInstance->{ldap} = new Net::LDAP('ldap.example.com');
    $ldapInstance->{ldap}->mock_root_dse(namingContexts => 'dc=example,dc=com');
}

sub runtests
{
    my ($class) = @_;

    shift @_;
    ldap_mockify {
        return $class->SUPER::runtests(@_);
    }
}

1;
