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

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Validate;

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

      return [qw(caPassphrase reCAPassphrase)];

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
      my $caPass = $self->param('caPassphrase');
      my $reCAPass = $self->param('reCAPassphrase');

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
          throw EBox::Exceptions::External(__x('CA Passphrase should be at least {length} characters',
                                               length => MIN_PASS_LENGTH));
      }

      unless ($days > 0) {
          throw EBox::Exceptions::External(__x('Days to expire ({days}) must be '
                                               . 'a positive number',
                                               days => $days));
      }

      my $retVal = $ca->createCA( orgName       => $orgName,
                                  days          => $days,
                                  caKeyPassword => $caPass,
                                );

      if (not defined($retVal) ) {
          throw EBox::Exceptions::External(__('Problems creating Certification Authority has happened'));
      }

  }

1;
