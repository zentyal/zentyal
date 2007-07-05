package EBox::GConfModule::TestStub;
# Description:
# 
use strict;
use warnings;

use Test::MockObject;
use List::Util qw(first);
use Params::Validate;
use EBox::GConfModule;


my %config;

# TODO:
# -defaults and schemas not supported
# -gconf types not supported 



sub fake
{
    Test::MockObject->fake_module('EBox::GConfModule',
		 '_gconf_wrapper' => \&_mockedGConfWrapper,
		 '_delete_dir_internal' => \&_mockedDeleteDirInternal ,
		 '_backup' => sub {} ,
		 'hash_from_dir' => \&_mockedHashFromDir,  
		);
}

sub unfake
{
  delete $INC{'EBox/GConfModule.pm'};
  eval 'use EBox::GConfModule';
  $@ and die "Error reloading EBox::GConfModule: $@";
}


my %subByGConfMethod = (
			get        => \&_getEntry,

			get_bool   => \&_getEntry,
			set_bool   => \&setEntry,
			get_int    => \&_getEntry,
			set_int    => \&setEntry,
			get_string => \&_getEntry,
			set_string => \&setEntry,

		
			get_list   => \&_getEntry,
			set_list   => \&_setList,

			unset      => \&_unsetEntry,

			dir_exists  => \&_dirExists,
			all_entries => \&_allEntries,
			all_dirs    => \&_allDirs,

   );

sub _mockedGConfWrapper
{
    my ($self, $method, @params) = @_;

    (exists $subByGConfMethod{$method}) or  die "GConf method $method was not available";
    my $methodSub_r = $subByGConfMethod{$method};

    my $scalar;
    my @array;

    my $ret = wantarray;
    eval { 
	if ($ret){
	    @array = $methodSub_r->(@params);
	} else {
	    $scalar = $methodSub_r->(@params);
	}	
    };
    if ($@) {
	throw EBox::Exceptions::Internal("gconf error using function "
					 . "$method and params @params"
					 . "\n $@");
    }

    return wantarray ? @array : $scalar;	
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
    }
    else {
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
