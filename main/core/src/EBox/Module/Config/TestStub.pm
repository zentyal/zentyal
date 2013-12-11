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

package EBox::Module::Config::TestStub;

use Test::MockObject;
use List::Util qw(first);
use Params::Validate;
use EBox::Module::Config;
use EBox::Exceptions::Internal;

my %config;

# TODO:
# -defaults and schemas not supported
# -gconf types not supported

sub fake
{
    Test::MockObject->fake_module('EBox::Module::Config',
		 '_gconf_wrapper' => \&_mockedGConfWrapper,
		 '_delete_dir_internal' => \&_mockedDeleteDirInternal ,
		 'hash_from_dir' => \&_mockedHashFromDir,
		 '_all_entries'    => sub {
		                         my ($self, $key) = @_;
					 $key = $self->_key($key);
					 return _allEntries($key);
		                         },
	);
}

sub unfake
{
    delete $INC{'EBox/Module/Config.pm'};
    eval 'use EBox::Module::Config';
    $@ and die "Error reloading EBox::Module::Config: $@";
}

my %subByGConfMethod = (
                        get => {
                                sub_r => \&_getEntry,
                                type  => undef,
                                returnValueHash => 1,
                               },

                        get_bool  => {
                                      sub_r =>  \&_getEntry,
                                      type  => 'bool',
                                      returnValueHash => 1,
                                     },
                        set_bool  => {
                                      sub_r =>  \&setEntry,
                                      type  => 'bool',
                                      returnValueHash => 0,
                                     },
                        get_int   => {
                                      sub_r =>  \&_getEntry,
                                      type  => 'int',
                                      returnValueHash => 1,
                                     },
                        set_int   => {
                                      sub_r =>  \&setEntry,
                                      type  => 'int',
                                      returnValueHash => 0,
                                     },
                        get_string=> {
                                      sub_r =>  \&_getEntry,
                                      type  => 'string',
                                      # Another irregularity:
                                      # EBox::Module::Config::get_string calls
                                      #  get_string in GconfWrapper instead of
                                      # get
                                      returnValueHash => 0,
                                     },
                        set_string=> {
                                      sub_r =>  \&setEntry,
                                      type  => 'string',
                                      returnValueHash => 0,
                                     },

                        get_list  => {
                                      sub_r =>  \&_getEntry,
                                      type  => 'list',
                                      # calls the warpper with uses get_list
                                      # instead of 'get'
                                      returnValueHash => 0,
                                     },
                        set_list  => {
                                      sub_r =>  \&_setList,
                                      type  => 'list',
                                      returnValueHash => 0,
                                     },

                        unset     => {
                                      sub_r =>  \&_unsetEntry,
                                      type  => undef,
                                      returnValueHash => 0,
                                     },

                        dir_exists => {
                                       sub_r =>  \&_dirExists,
                                       type  => undef,
                                       returnValueHash => 0,
                                      },
                        all_entries=> {
                                       sub_r =>  \&_allEntries,
                                       type  => undef,
                                       returnValueHash => 0,
                                      },
                        all_dirs   => {
                                       sub_r =>  \&_allDirs,
                                       type  => undef,
                                       returnValueHash => 0,
                                      },
);

sub _mockedGConfWrapper
{
    my ($self, $method, @params) = @_;

    (exists $subByGConfMethod{$method}) or  die "GConf method $method was not available";

    # some simple getters are now calling to the 'get' method, this is to found
    # the equivalent calelr so we don't lose type information
    if ($method eq 'get') {
        my ($package, $filename, $line, $parentMethod) = caller(1);

        if ($parentMethod =~ m/^EBox::Module::Config::_get_/) {
            $method = $parentMethod;
            $method =~ s/^EBox::Module::Config::_//;
        }
    }

    my $methodSub_r = $subByGConfMethod{$method}->{'sub_r'};
    my $type        = $subByGConfMethod{$method}->{'type'};
    my $returnValueHash    = $subByGConfMethod{$method}->{'returnValueHash'};

    my $value;
    my $wantarray = wantarray();

    eval {
        if ($wantarray){
            my @array = $methodSub_r->(@params);
            $value = \@array;
        } else {
            my $scalar = $methodSub_r->(@params);
            $value = $scalar;
        }
    };
    if ($@) {
        throw EBox::Exceptions::Internal("gconf error using function "
                                         . "$method and params @params"
                                         . "\n $@");
    }

    if (not $returnValueHash) {
        return $wantarray ? @{ $value } : $value;
    }

    # undef must have some special tratment for some types...
    if (not defined $value) {
        if ($type eq 'int') {
            # no initialzed ints must return 0 only undef uif the type isn't
            # int, but we dont mock the storage tpyes (we assuem that al ldata
            # is of the coorect type)
            $value = 0;
        }
        elsif ($type eq 'bool') {
            # do nothing, undef is a vlaid bool value
        }
        else {
            return undef;
        }
    }

    my $resHash = {
                     value => $value,
                     type => $type
                  };

    return $resHash;
}

# XXX defaults not supported
sub _unsetEntry
{
    my ($key) = @_;
    delete $config{$key};
}

sub setEntry
{
    my ($key, $value) = @_;
    validate_pos(@_, 1, 1);

    $config{$key} = $value;
}

sub _getEntry
{
    my ($key) = @_;

    if (exists $config{$key} ) {
        return $config{$key};
    } else {
        return undef;
    }

}

# for now we ignore the type...
sub _setList
{
    my ($key, $type, $val) = @_;
    $config{$key} = $val;
}

sub _allEntries
{
    my ($key) = @_;
    my @entries = grep { m{^$key/[^/\s]+$}   } keys %config;
    @entries = _removeModulePrefix($key, @entries);

    return @entries;
}

sub _allDirs
{
    my ($key) = @_;
    my @dirs    = map  {
	if ( m{^($key/[^/\s]+)/[^/\s]+}  ) {
	     $1;
	}
	else {
	     ();
	}
    } keys %config;

    @dirs = _removeModulePrefix($key, @dirs);

    my %uniqDirs = map { $_ => 1  } @dirs;
    return keys %uniqDirs;
}

sub _removeModulePrefix
{
    my ($dir, @entries) = @_;

    my $prefix = undef;
    foreach my $possiblePrefix (qw(modules state)) {
        if ($dir =~ m{^/ebox(-ro)?/$possiblePrefix}) {
            $prefix = $possiblePrefix;
        }
    }

    defined $prefix or die "Not correct prefix found in key $dir";

    @entries = map { s{^/ebox(-ro)?/$prefix/[^/\s]+/}{}; $_  } @entries;

    return @entries;
}

sub _dirExists
{
    my ($key) = @_;

    my $dirExists;
    $dirExists = first { m{$key/[^/\s]+}  } keys %config;

    return defined $dirExists ? 1 : 0;
}

sub _mockedDeleteDirInternal
{
    my ($self, $dir) = @_;
    # very ineffcient:
    my $target = qr{^$dir};
    foreach my $key (keys %config) {
        if ($key =~ m{$target} ) {
            delete $config{$key};
        }
    }
}

# faking get in gconfwarpper seems to be not enough....
sub _mockedHashFromDir
{
    my ($self, $dir) = @_;
    $dir = $self->_key($dir);

    my @entries = @{ $self->all_entries_base($dir) };
    my %dirHash = map {
        my $entry   =  $_;
        my $key     = "$dir/$entry";
        my $value = _getEntry($key);

        ($entry, $value)
    } @entries;

    return \%dirHash;
}

# subs to mangle configuration for testing:

sub setConfig
{
    %config = @_;
}

sub dumpFakeConfig
{
    warn "name deprecated, use dumpConfig instead";
    return dumpConfig(@_);
}

sub dumpConfig
{
    my @configList = %config;
    return \@configList
}

1;
