# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::GConfModule::Partition;
# package: create a kind of pseudo-partition in the configuration tree of a module
use strict;
use warnings;
use EBox::GConfModule;

#
# Constructor: new
#
#   Creates a new module partition
#
#  Parametes:
#        $base        - the portion of configuration namespace used for the partition
#        $fullModule  - a instance of the GConfModule to which belongs the partition
#
# Returns:
#
#    a blessed instance of the partition
sub new
{
    my ($class, $base, $fullModule) = @_;
    defined $base or
      throw EBox::Exceptions::MissingArgument('base');
    defined $fullModule or
      throw EBox::Exceptions::MissingArgument('fullModule');
    $fullModule->isa('EBox::GConfModule') or
      throw EBox::Exceptions::InvalidData(
				      data => 'GConfModule',
				      value => $fullModule,
				      advice => 'A instance of a subclass of EBox::GConfModule is expected',
				     );

    my $dirExists = $class->_checkBaseDirExists($fullModule, $base);

    if (not $dirExists ) {
	throw EBox::Exceptions::Internal("Tried to instantiate a module partition with a space not found in module configuration: $base");
    }

    my $self = {
		fullModule   => $fullModule,
		confKeysBase => $base,
	       };
    bless $self, $class;

    return $self;
}


sub _checkBaseDirExists
{
  my ($class, $fullModule, $base) = @_;
  return $fullModule->dir_exists($base);
}


sub confKey
{
    my ($self, $key) = @_;
    return $self->{confKeysBase} . "/$key";
}

#
# Method: fullModule
#
#   gets the module which contains the partition
#
# Returns:
#
#    the module which contais the partition
sub fullModule
{
    my ($self) = @_;
    return $self->{fullModule};
}

sub _fullModuleMethod
{
  my ($self, $method, @params) = @_;
  return $self->fullModule->$method(@params);
}

#
# Method: confKeysBase
#
#   gets the configuration directory where the partition's configuration resides
#
# Returns:
#
#    the partition's configuration directory as string
sub confKeysBase
{
  my ($self, $key) = @_;
  return $self->{confKeysBase};
}

sub getConfString
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('get_string', $key);
}

sub setConfString
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('set_string', $key, $value);
}


sub getConfInt
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('get_int', $key);
}

sub setConfInt
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('set_int', $key, $value);
}


sub confDirExists
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->_fullModuleMethod('dir_exists', $key);
}


sub deleteConfDir

{    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->_fullModuleMethod('delete_dir', $key);
}

sub allConfEntriesBase
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->_fullModuleMethod('all_entries_base', $key);
}


sub unsetConf
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->_fullModuleMethod('unset', $key);
}


sub getConfBool
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('get_bool', $key);
}

sub setConfBool
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->_fullModuleMethod('set_bool', $key, $value);
}


sub getConfList
{
  my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->_fullModuleMethod('get_list', $key);
}

sub setConfList
{
  my ($self, $key, $type, $values_r) = @_;
  $key = $self->confKey($key);
  return $self->_fullModuleMethod('set_list', $key, $type, $values_r);
}


sub hashFromConfDir
{
  my ($self, $key) = @_;
  $key = $self->confKey($key);
  return $self->_fullModuleMethod('hash_from_dir', $key);
}


1;
