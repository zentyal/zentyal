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

package EBox::CA::CGI::RevokeCertificate;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
# For exceptions
use TryCatch;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;

# Method: new
#
#       Constructor for RevokeCertificate CGI
#
# Returns:
#
#       RevokeCertificate - The object recently created
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority'), @_);

    $self->{chain} = "CA/Index";
    bless($self, $class);

    return $self;
}

sub redirectOnNoParams
{
    return 'CA/Index';
}

# Process the HTTP query
# Templates that come from: forceRevoke.mas and formRevoke.mas

sub _process
{
    my $self = shift;

    return unless (@{$self->params()});

    # If it comes from forceRevoke with a cancel button
    if (defined($self->param('cancel'))) {
        $self->setRedirect('CA/Index');
        $self->setMsg( __("The certificate has NOT been revoked.") );
        my $request = $self->request();
        my $parameters = $request->parameters();
        $parameters->clear();
        return;
    }

    my $ca = EBox::Global->modInstance('ca');

    $self->_requireParam('isCACert', __('Boolean indicating Certification Authority Certificate') );
    $self->_requireParam('reason', __('Reason') );

    my $commonName = $self->unsafeParam('commonName');
    # We have to check it manually
    if (not defined($commonName) or $commonName eq '') {
        throw EBox::Exceptions::DataMissing(data => __('Common Name'));
    }
    # Only valid chars minus '/' plus '*' --> security risk
    unless ($commonName =~ m{^[\w .?&+:\-\@\*]*$}) {
        throw EBox::Exceptions::External(__('The input contains invalid ' .
                    'characters. All alphanumeric characters, ' .
                    'plus these non alphanumeric chars: .?&+:-@* ' .
                    'and spaces are allowed.'));
    }

    # Transform %40 in @
    $commonName =~ s/%40/@/g;
    # Transform %20 in space
    $commonName =~ s/%20/ /g;

    my $isCACert = $self->param('isCACert');
    my $reason = $self->param('reason');
    my $caPassphrase = $self->param('caPassphrase');
    $caPassphrase = undef if ($caPassphrase and $caPassphrase eq '');
    my @array = ();

    my $retValue;
    my $retFromCatch = undef;

    if (defined($self->param("revokeForce"))) {
        # If comes from a forceRevoke with forceRevoke button
        if ($isCACert) {
            $ca->revokeCACertificate(reason        => $reason,
                                     caKeyPassword => $caPassphrase,
                                     force         => 1);
        } else {
            $ca->revokeCertificate(commonName    => $commonName,
                                   reason        => $reason,
                                   caKeyPassword => $caPassphrase,
                                   force         => 1);
        }
    } else {
        # If it comes from a formRevoke.mas
        try {
            if ($isCACert) {
                $retValue = $ca->revokeCACertificate(reason => $reason,
                                                     caKeyPassword => $caPassphrase);
            } else {
                $retValue = $ca->revokeCertificate(commonName    => $commonName,
                                                   caKeyPassword => $caPassphrase,
                                                   reason        => $reason);
            }
        } catch (EBox::Exceptions::DataInUse $e) {
            $self->{template} = '/ca/forceRevoke.mas';
            $self->{chain} = undef;
            my $cert = $ca->getCertificateMetadata( cn => $commonName );
            push (@array, 'metaDataCert' => $cert);
            push (@array, 'isCACert'   => $isCACert);
            push (@array, 'reason'     => $reason);
            push (@array, 'caPassphrase' => $caPassphrase);
            $self->{params} = \@array;
            $retFromCatch = 1;
        }
    }

    if (not $retFromCatch) {
        my $msg = __("The certificate has been revoked");
        $msg = __("The CA certificate has been revoked") if ($isCACert);
        $self->setMsg($msg);
        # No parameters to send to CA/Index
        my $request = $self->request();
        my $parameters = $request->parameters();
        $parameters->clear();
    }
}

1;
