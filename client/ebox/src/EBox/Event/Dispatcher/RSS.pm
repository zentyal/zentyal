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

package EBox::Event::Dispatcher::RSS;

# Class: EBox::Dispatcher::RSS
#
# This class is a dispatcher which stores the eBox events in a single
# file within the channel
#

use base 'EBox::Event::Dispatcher::Abstract';

use strict;
use warnings;

# eBox uses
use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;

################
# Core modules
################
use Sys::Hostname;
use Fcntl qw(:flock);
use POSIX qw(strftime);

################
# Dependencies
################
use XML::RSS;

# Constants
use constant {
    RSS_FILE => EBox::Config::dynamicRSS() . 'alerts.rss',
    RSS_LOCK_FILE => EBox::Config::tmp() . 'alerts.rss.lock',
    CHANNEL_TTL => 5,
    MAX_RSS_ITEMS => 500
};


# Class data
our $LockFH;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::RSS>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::RSS> - the newly created object
#
sub new
{

    my ($class) = @_;

    my $self = $class->SUPER::new('ebox-events');
    bless( $self, $class );

    return $self;

}

# Method: configured
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configured>
#
sub configured
{

    my ($self) = @_;

    return 1;

}

# Method: send
#
#        Send the event to the admin using Jabber protocol
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::send>
#
sub send
  {

      my ($self, $event) = @_;

      defined ( $event ) or
        throw EBox::Exceptions::MissingArgument('event');

      $self->_addEventToRSS($event);

      return 1;

  }

# Group: Static class methods

# Method: RSSFilePath
#
#       Get the RSS file path
#
# Returns:
#
#       String - the RSS file path
#
sub RSSFilePath
{
    return RSS_FILE;
}

# Method: LockRSSFile
#
#       Lock the RSS file for working with it. This call is blocking
#       is said so until the other process releases the lock using
#       <EBox::Event::Dispatcher::RSS::UnlockRSSFile>
#
# Parameters:
#
#       exclusive - boolean indicating if the lock for the RSS file is
#       asked exclusively or not
#
sub LockRSSFile
{
    my ($class, $exclusive) = @_;

    open($LockFH, '+>', $class->_RSSLockFilePath())
      or throw EBox::Exceptions::Internal('Cannot open lock file '
                                          . $class->_RSSLockFilePath()
                                          . ": $!");
    my $flag = $exclusive ? LOCK_EX : LOCK_SH;

    flock($LockFH, $flag)
      or throw EBox::Exceptions::Lock($class);

}

# Method: UnlockRSSFile
#
#       Release the lock for the RSS file after working with it. This
#       call must be done after locking the RSS file using
#       <EBox::Event::Dispatcher::RSS::LockRSSFile>
#
sub UnlockRSSFile
{
    my ($class) = @_;

    my $flag = LOCK_UN;

    flock($LockFH, $flag);
    close($LockFH);

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
#        <EBox::Event::Component::ConfigureModel>
#
sub ConfigureModel
{

    return 'RSSDispatcherConfiguration';

}


# Group: Protected methods

# Method: _receiver
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_receiver>
#
sub _receiver
{

    return __x('RSS file: {path}',
               path => '<a href="/dynamic-data/feed/alerts.rss">Alerts</a>');

}

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
{

    return __('RSS');

}

# Method: _enable
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::_enable>
#
sub _enable
{

    my ($self) = @_;

    # Check how the public access is done
    my $confModel = $self->configurationSubModel(__PACKAGE__); 

    my $allowedType = $confModel->allowedType();

    if ( $allowedType->selectedType() eq 'allowedNobody' ) {
	EBox::warn('There are no allowed readers for the RSS');
    }

    return 1;
}

# Group: Private methods

# Add the event to the RSS file, if it does exists, create a new one
sub _addEventToRSS
{

    my ($self, $event) = @_;

    my $confModel = $self->configurationSubModel(__PACKAGE__); 

    my $rss = new XML::RSS(version => '2.0');
    # Locking exclusively
    $self->LockRSSFile(1);

    my $rssComplaintDate = $self->_currentDate();
	my $create = undef;
	
    if ( not -r RSS_FILE ) {
        $create = 1;
    } else {
        eval '$rss->parsefile(RSS_FILE)';
        if ($@) {
            unlink(RSS_FILE);
            $create = 1;
            $rss = new XML::RSS(version => '2.0');
        }
    }
	
    if ($create) {
        # Create the channel if it does not exist
        $rss->channel(title         => __x('eBox alerts channel for {hostname}',
                                         hostname => hostname()),
                      link          => $confModel->linkValue(),
                      description   => __('This channel tracks what happens on '
                                          . 'this eBox machine along the time'),
                      language      => $self->_currentLanguage(),
#                      pubDate       => $rssComplaintDate,
                      lastBuildDate => $rssComplaintDate,
                      ttl           => CHANNEL_TTL,
                     );
        $rss->image(title       => 'eBox platform',
                    url         => 'http://trac.ebox-platform.com/chrome/common/ebox-logo.png',
                    link        => 'http://ebox-platform.com',
                    description => 'eBox platform',
                    alt         => 'eBox platform',
                   );

    }
    # Update the lastBuildDate and pubDate
    $rss->channel(pubDate       => $rssComplaintDate,
                  lastBuildDate => $rssComplaintDate
                 );

    my $descriptionStr = __x('The event has happened in eBox {hostname} '
                             . 'from {source}',
                             hostname => hostname(),
                             source   => $event->source());
    $descriptionStr .= '<br><br>' . __x('Go to your {url} to check its status.',
                                    url => '<a href="' . $confModel->linkValue()
                                    . '">eBox</a>');
    $rss->add_item(
                   description => $descriptionStr,
                   title       => ($event->level() . ' : ' . $event->message()),
                   pubDate     => $event->strTimestamp(),
                   category    => $event->source(),
                   guid        => $event->source() . '-' . $event->timestamp(),
                  );

    # Remove entries to MAX_RSS_ITEMS
    my $length = $rss->{'num_items'};
    if ($length > MAX_RSS_ITEMS) {
        splice(@{$rss->{'items'}}, - MAX_RSS_ITEMS, ($length - MAX_RSS_ITEMS));
    }

    $rss->save(RSS_FILE);

    $self->UnlockRSSFile();

}

sub _RSSLockFilePath
{
    return RSS_LOCK_FILE;
}

# Get the current language
sub _currentLanguage
{
    my $lang = $ENV{LANG};
    $lang =~ s:\..*$::g;
    $lang =~ s:_:-:g;

    return $lang;
}

# Get the current date in RSS 2.0 complaint way
sub _currentDate
{
    return strftime("%a, %d %b %Y %T %z", localtime(time()));

}

1;
