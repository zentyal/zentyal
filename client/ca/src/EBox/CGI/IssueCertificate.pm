# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::CGI::CA::IssueCertificate;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Exceptions::DataMissing;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use Error qw(:try);

# Constants:
use constant MIN_PASS_LENGTH => 5;


# Method: new
#
#       Constructor for IssueCertificate CGI
#
# Returns:
#
#       IssueCertificate - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    $self->{chain} = "CA/Index";
    bless($self, $class);

    return $self;

  }

# Process the HTTP query

sub _process
  {

    my $self = shift;

    my $ca = EBox::Global->modInstance('ca');

    my $issueCA = $self->param('caNeeded');
    $issueCA = 0 unless defined($issueCA);

    my $name = $self->unsafeParam('name');
    unless (defined($name) and ($name ne '')) {
        if ($issueCA) {
            throw EBox::Exceptions::DataMissing(data =>  __('Organization Name') );
        } else {
            throw EBox::Exceptions::DataMissing(data =>  __('Common Name') );
        }
    }
    # Common parameters
    $self->_requireParam('expiryDays', __('Days to expire') );

    my $days = $self->param('expiryDays');
    my $caPass = $self->param('caPassphrase');
    my $reCAPass = $self->param('reCAPassphrase');

    if ( $issueCA ) {
      # Check passpharses
      if ( defined ( $caPass ) and defined ( $reCAPass )) {
        unless ( $caPass eq $reCAPass ) {
          throw EBox::Exceptions::External(__('CA passphrases do NOT match'));
        }
        # Set no pass if the pass is empty
        if ( $caPass eq '' ) {
          $caPass = undef;
        }
        # Check length
        if ( defined ( $caPass ) and length ( $caPass ) < MIN_PASS_LENGTH ) {
          throw EBox::Exceptions::External(__x('CA Passphrase should be at least {length} characters',
                                               length => MIN_PASS_LENGTH));
        }
      }

    }

    $caPass = undef if ( $caPass eq '' );

    unless ( $days > 0) {
        throw EBox::Exceptions::External(__x('Days to expire ({days}) must be '
                                             . 'a positive number',
                                             days => $days));
    }

    # Only valid chars minus '/' plus '*' --> security risk
    unless ( $name =~ m{^[\w .?&+:\-\@\*]*$} ) {
      throw EBox::Exceptions::External(__('The input contains invalid ' .
					  'characters. All alphanumeric characters, ' .
					  'plus these non alphanumeric chars: .?&+:-@* ' .
					  'and spaces are allowed.'));
    }

    my $retValue;
    if ($issueCA) {
      $retValue = $ca->issueCACertificate( orgName       => $name,
					   days          => $days,
                                           caKeyPassword => $caPass,
					   genPair       => 1);
    } else {
      $retValue = $ca->issueCertificate( commonName    => $name,
					 days          => $days,
                                         caKeyPassword => $caPass,
                                       );
    }

    my $msg = __("The certificate has been issued");
    $msg = __("The new CA certificate has been issued") if ($issueCA);
    $self->setMsg($msg);

  }

1;
