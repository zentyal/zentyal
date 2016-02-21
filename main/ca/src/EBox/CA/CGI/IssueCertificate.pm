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

package EBox::CA::CGI::IssueCertificate;

use base 'EBox::CGI::ClientBase';

use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Global;
use EBox::Validate;
use TryCatch;

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
    my $self = $class->SUPER::new('title' => __('Certification Authority'),
                                  @_);

    $self->{chain} = 'CA/Index';
    bless($self, $class);

    return $self;
}

sub redirectOnNoParams
{
    return 'CA/Index';
}

# Method: requiredParameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    return ['name', 'expiryDays', 'certificate'];
}

# Method: optionalParameters
#
# Overrides:
#
#     <EBox::CGI::Base::optionalParameters>
#
sub optionalParameters
{
    return [
            'caNeeded', 'caPassphrase', 'reCAPassphrase',
            'countryName', 'stateName', 'localityName',
            'subjectAltName'];
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
    if (not @{ $self->params()  }) {
        return;
    }
    foreach my $required ('name', 'expiryDays', 'certificate' ) {
        $self->_requireParam($required);
    }

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
    my $days = $self->param('expiryDays');
    my $subjAltName = $self->unsafeParam('subjectAltName');
    my $countryName = $self->param('countryName');
    my $localityName = $self->param('localityName');
    my $stateName = $self->param('stateName');
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

    $caPass = undef if ( (not defined($caPass)) or $caPass eq '' );

    unless ( $days > 0) {
        throw EBox::Exceptions::External(__x('Days to expire ({days}) must be '
                                             . 'a positive number',
                                             days => $days));
    }

    # Only validate the following format for subjectAltName
    # <type>:<value>,<type>:value
    # type = DNS, IP, email
    # value = DNS   -> DomainName
    #         IP    -> IP address
    #         email -> email address
    my @subjAltNamesParam;
    if ( $subjAltName ) {
        my @subjAltNames = split(/,/, $subjAltName);
        foreach my $subAlt (@subjAltNames) {
            my ($type, $value) = split(/:/, $subAlt);
            if (not $value) {
                throw EBox::Exceptions::External(__('The Subject Alternative Name parameter '
                                                . 'must follow this pattern: type:value, type:value'));
            }
            # autocorrect bad case typess
            if (($type eq 'dns') or ($type eq 'ip')) {
                $type = uc $type;
            } elsif ($type eq 'EMAIL') {
                $type =  lc $type;
            }
            push(@subjAltNamesParam, { type => $type, value => $value });
        }
    }

    my $retValue;
    if ($issueCA) {
      $retValue = $ca->issueCACertificate( orgName       => $name,
                                           days          => $days,
                                           countryName   => $countryName,
                                           localityName  => $localityName,
                                           stateName     => $stateName,
                                           caKeyPassword => $caPass,
                                           genPair       => 1);
    } else {
      $retValue = $ca->issueCertificate( commonName    => $name,
                                         days          => $days,
                                         caKeyPassword => $caPass,
                                         subjAltNames  => \@subjAltNamesParam,
                                       );
    }

    my $msg = __("The certificate has been issued.");
    $msg = __("The new CA certificate has been issued.") if ($issueCA);
    $self->setMsg($msg);
    # Delete all CGI parameters for CA/Index
    my $request = $self->request();
    my $parameters = $request->parameters();
    $parameters->clear();
}

1;
