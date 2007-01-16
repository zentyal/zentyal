package EBox::OpenVPN::ModulePartition; 
# this module may become EBox::GConfModule if other modules found it useful
# package: create a kind of pseudo-partition in the configuration tree of a module
use strict;
use warnings;
use EBox::GConfModule;

sub new
{
    my ($class, $base, $fullModule) = @_;
    
    if (!$fullModule->dir_exists($base) ) {
	throw EBox::Exceptions::Internal("Tried to instantiate a module partition with a space not found in module configuration: $base");
    }

    my $self = { fullModule => $fullModule, confKeysBase => $base   };
    bless $self, $class;

    return $self;
}


sub confKey
{
    my ($self, $key) = @_;
    return $self->{confKeysBase} . "/$key";
}

sub fullModule
{
    my ($self) = @_;
    return $self->{fullModule};
}

sub getConfString
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->fullModule->get_string($key);
}

sub setConfString
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->fullModule->set_string($key, $value);
}


sub getConfInt
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->fullModule->get_int($key);
}

sub setConfInt
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->fullModule->set_int($key, $value);
}


sub confDirExists
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->fullModule->dir_exists($key);
}


sub deleteConfDir

{    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->fullModule->delete_dir($key);
}

sub allConfEntriesBase
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->fullModule->all_entries_base($key);
}


sub unsetConf
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    return $self->fullModule->unset($key);
}


sub getConfBool
{
    my ($self, $key) = @_;
    $key = $self->confKey($key);
    $self->fullModule->get_bool($key);
}

sub setConfBool
{
    my ($self, $key, $value) = @_;
    $key = $self->confKey($key);
    $self->fullModule->set_bool($key, $value);
}


1;
