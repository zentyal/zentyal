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

package EBox::Event::Watcher::DiskFreeSpace;

# Class: EBox::Event::Watcher::DiskFreeSpace
#
#   This class is a watcher which checks if a partition has no free
#   space left. The measure is done in percentages which is
#   configurable by the user.
#


use base 'EBox::Event::Watcher::Base';

use EBox::Event;
use EBox::Event::Watcher::Base;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::FileSystem;

use Filesys::Df;
use Error qw(:try);
use Perl6::Junction qw(any);


use constant SPACE_THRESHOLD => 1024; # a file system is considered full with it has
                                  # less than this space (in  1K blocks) free


# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::DiskFreeSpace>
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::new>
#
# Parameters:
#
#        - non parameters
#
# Returns:
#
#        <EBox::Event::Watcher::State> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new(
                                    period      => 120,
                                    domain      => 'ebox-events',
                                   );
      bless( $self, $class);

      return $self;

  }

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'model';
}


# Method: ConfigureModel
#
# Overrides:
#
#       <EBox::Event::Component::ConfigureModel>
#
sub ConfigureModel
{
    return 'DiskFreeWatcherConfiguration';
}

# Method: run
#
#        Check if any partition is full
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if all partitions have sufficent space left
#
#        array ref - <EBox::Event> an event is sent when some
#        partitions does not have space left
#
sub run
{
  my ($self) = @_;

  my @events;
  my $eventMod = EBox::Global->modInstance('events');

  my %fileSys = %{ $self->_filesysToMonitor() };
  while (my ($fs, $properties) = each %fileSys) {
    my $key      = _eventKey($fs);
    my $eventHappened = $eventMod->st_get_bool($key);

    my $df = df($properties->{mountPoint});
    if ($self->_isFSFull($df) and not $eventHappened) {
      $eventMod->st_set_bool($key, 1);

      push @events,
	new EBox::Event(
			message => __x('The file system {fs}, mounted on {mp},'.
				       ' has no space left',
				       fs => $fs,
				       mp => $properties->{mountPoint},
				      ),
			level   => 'error',
                        source  => $self->name(),
		       );
    }
    elsif ($eventHappened) {
      # disable key bz the problem has solved
      $eventMod->st_set_bool($key, 0);
    }
  }

  return \@events if @events;
  return undef;
}

# Group: Protected methods

# Method: _name
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_name>
#
# Returns:
#
#        String - the event watcher name
#
sub _name
  {

      return __('Free storage space');

  }

# Method: _description
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_description>
#
# Returns:
#
#        String - the event watcher detailed description
#
sub _description
  {

      return __('Check if any disk partition ' .
                'has no storage space left');

  }

# Group: Private methods

sub _eventKey
{
  my ($fs) = @_;

  # Substitute slashes because of GConf key structure
  $fs =~ s{/}{S}g;

  return "event_fired/partition_full/$fs";
}


sub _filesysToMonitor
{
  my %fileSys = %{  EBox::FileSystem::fileSystems() };


  foreach my $fs (keys %fileSys) {
    # remove not-device filesystems
    if (not $fs =~ m{^/dev/}) {
      delete $fileSys{$fs};
      next;
    } 

  # remove removable media filesystems
    my $mpoint = $fileSys{$fs}->{mountPoint};
    if ($mpoint =~ m{^/media/}) {
      delete $fileSys{$fs};
      next;
    }

    # we don't care about space shortage in read only file systems
    my @options = split ',', $fileSys{$fs}->{options};
    if ('ro' eq any @options) {
      delete $fileSys{$fs};
      next;
    }

  }

  return \%fileSys;
}

# Method to get if a filesystem is full of space or not
sub _isFSFull
{
  my ($self, $df) = @_;

#  return ($df->{bfree} < SPACE_THRESHOLD);
  return ( 100 - $df->{per} < $self->_spaceThreshold() );

}

# Method to get the configurable minimum percentage before the user is
# notified because of the free space lack
sub _spaceThreshold
{
    my ($self) = @_;

    return $self->configurationSubModel(__PACKAGE__)->spaceThreshold();
}


1;
