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

package EBox::CGI::CA::CreateCA;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox;

# Constants:
use constant MIN_PASS_LENGTH => 5;

# Method: new
#
#       Constructor for CreateCA CGI
#
# Returns:
#
#       CreateCA - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority Management'),
				  @_);

    $self->{domain} = 'ebox-ca';
    bless($self, $class);

    $self->setChain( 'CA/Index' );

    return $self;

  }

# Method: requiredParameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
  {

      my ($self) = @_;

      return [qw(orgName expiryDays ca)]

  }

# Method: optionalParameters
#
# Overrides:
#
#     <EBox::CGI::Base::optionalParameters>
#
sub optionalParameters
  {

      my ($self) = @_;

      return [qw(caPasspharse reCAPasspharse)];

  }


# Method: actuate
#
# Overrides:
#
#     <EBox::CGI::Base::actuate>
#
sub actuate
  {

      my ($self) = @_;

      my $gl = EBox::Global->getInstance();
      my $ca = $gl->modInstance('ca');

      my $orgName = $self->param('orgName');
      my $days = $self->param('expiryDays');
      my $caPass = $self->param('caPasspharse');
      my $reCAPass = $self->param('reCAPasspharse');

      # Check passpharses
      if ( defined ( $caPass ) and defined ( $reCAPass )) {
          unless ( $caPass eq $reCAPass ) {
              throw EBox::Exceptions::External(__('CA passphrases do NOT match'));
          }
          # Set no pass if the pass is empty
          if ( $caPass eq '' ) {
              $caPass = undef;
          }
      }

      # Check length
      if ( defined ( $caPass ) and length ( $caPass ) < MIN_PASS_LENGTH ) {
          throw EBox::Exceptions::External(__x('CA Passpharse should be at least {length} characters',
                                               length => MIN_PASS_LENGTH));
      }

      if ( $days <= 0 ) {
          throw EBox::Exceptions::External(__('Days to expire MUST be a natural number'));
      }

      my $retVal = $ca->createCA( orgName       => $orgName,
                                  days          => $days,
                                  caKeyPassword => $caPass,
                                );

      if (not defined($retVal) ) {
          throw EBox::Exceptions::External(__('Problems creating Certification Authority has happened'));
      }

  }

# Process the HTTP query
#sub _process
#  {
#
#    my $self = shift;
#
#    my $ca = EBox::Global->modInstance('ca');
#
#    $self->_requireParam('orgName', __('Organization Name') );
#    $self->_requireParam('expiryDays', __('Days to expire') );
#
#    my $orgName = $self->param('orgName');
#    my $days = $self->param('expiryDays');
#
#    if ( $days <= 0 ) {
#      throw EBox::Exceptions::External(__('Days to expire MUST be a natural number'));
#    }
#
#    my $retVal = $ca->createCA( orgName       => $orgName,
#				days          => $days);
#
#    if (not defined($retVal) ) {
#      throw EBox::Exceptions::External(__('Problems creating Certification Authority has happened'));
#    }
#
#  }

1;
