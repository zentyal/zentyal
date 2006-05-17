package EBox::GConfModule::Mock;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;
use List::Util qw(first);

my %config;
my $mockedModule;

# TODO:
# -defaults and schemas not supported
# -gconf types not supported 



sub mock
{
    if (defined $mockedModule) {
	unmock();
    }

    $mockedModule = new Test::MockModule('EBox::GConfModule');
    $mockedModule->mock('_gconf_wrapper' => \&_mockedGConfWrapper);
    $mockedModule->mock('_backup' => sub {} );

}

sub unmock
{
    $mockedModule->unmock_all();
}


my %subByGConfMethod = (
			get_bool   => \&_getEntry,
			set_bool   => \&_setEntry,
			get_int    => \&_getEntry,
			set_int    => \&_setEntry,
			get_string => \&_getEntry,
			set_string => \&_setEntry,
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

sub _setEntry
{
    my ($key, $value) = @_;

 
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



sub _allEntries
{
    my ($key) = @_;
    my @entries = grep { m{^$key/\w+$}   } keys %config; 
    @entries = _removeModulePrefix($key, @entries);
 
    return @entries;
}

sub _allDirs
{
    my ($key) = @_;
    my @dirs    = map  { 
	if ( m{^($key/\w+)/\w+}  ) {
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

    @entries = map { s{^/ebox(-ro)?/$prefix/\w+/}{}; $_  } @entries;

    return @entries;
}

sub _dirExists
{
    my ($key) = @_;

    my $dirExists;
    $dirExists = first { m{$key/\w+}  } keys %config;

    return defined $dirExists ? 1 : 0;
}



# subs to mangle configuration for testing:

sub setArbitraryEntry
{
    my ($key, $value) = @_;
    $config{$key} = $value;
}


sub setArbitraryConfig
{
    %config = @_;
}

sub dumpFakeConfig
{
    my @configList = %config;
    return \@configList
}

1;
