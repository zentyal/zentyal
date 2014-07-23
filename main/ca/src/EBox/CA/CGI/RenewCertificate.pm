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

package EBox::CA::CGI::RenewCertificate;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
# For exceptions
use TryCatch::Lite;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;

# Method: new
#
#       Constructor for RenewCertificate CGI
#
# Returns:
#
#       RenewCertificate - The object recently created
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority'), @_);

    bless($self, $class);
    return $self;
}

# Process the HTTP query
sub _process
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');

    if ($self->param('cancel')) {
        $self->setRedirect( 'CA/Index' );
        $self->setMsg( __("The certificate has NOT been renewed") );
        my $request = $self->request();
        my $parameters = $request->parameters();
        $parameters->clear();
        return;
    }

    my $jsonReply = $self->param('jsonReply');
    if ($jsonReply) {
        $self->{json} = { success => 0 };
    } else {
        $self->{chain} = "CA/Index";        
    }

    $self->_requireParam('isCACert', __('Boolean indicating Certification Authority Certificate') );
    $self->_requireParam('expireDays', __('Days to expire') );

    my $commonName = $self->unsafeParam('commonName');
    try {
        $ca->checkCommonName($commonName);
    } catch ($ex) {
        if ($jsonReply) {
            $self->{json}->{message} = "$ex";
        } else {
            $ex->throw();
        }
    }


    # Transform %40 in @
    $commonName =~ s/%40/@/g;
    # Transform %20 in space
    $commonName =~ s/%20/ /g;

    my $isCACert = $self->param('isCACert');
    my $expireDays = $self->param('expireDays');
    my $caPassphrase = $self->param('caPassphrase');
    $caPassphrase = undef if ( $caPassphrase eq '' );

    unless ($expireDays > 0) {
        my $failMsg = __x('Days to expire ({days}) must be '
                              . 'a positive number',
                              days => $expireDays);
        if ($jsonReply) {
            $self->{json}->{message} = $failMsg;
            return;
        } else {
            throw EBox::Exceptions::External($failMsg);            
        }
    }

    my $retValue;
    my $retFromCatch;
    if (defined ($self->param('renewForced'))) {
        if ($isCACert) {
            $retValue = $ca->renewCACertificate(days => $expireDays,
                                                caKeyPassword => $caPassphrase,
                                                force => 'true');
        } else {
            $retValue = $ca->renewCertificate(commonName => $commonName,
                                              days       => $expireDays,
                                              caKeyPassword => $caPassphrase,
                                              force      => 'true');
        }
    }
    else {
        try {
            if ($isCACert) {
                $retValue = $ca->renewCACertificate(days => $expireDays,
                                                    caKeyPassword => $caPassphrase);
            } else {
                $retValue = $ca->renewCertificate(commonName    => $commonName,
                                                 caKeyPassword => $caPassphrase,
                                                 days          => $expireDays);
            }
        } catch (EBox::Exceptions::DataInUse $ex) {
            if ($jsonReply) {
                $self->{json}->{message} = "$ex";
            } else {
                $self->{template} = '/ca/forceRenew.mas';
                $self->{chain} = undef;
                my $cert = $ca->getCertificateMetadata( cn => $commonName );
                my @array;
                push (@array, 'metaDataCert' => $cert);
                push (@array, 'expireDays'   => $expireDays);
                push (@array, 'caPassphrase' => $caPassphrase);
                $self->{params} = \@array;
            }
            $retFromCatch = 1;
        }
    }

    if (not $retFromCatch) {
        if (not defined($retValue)) {
            my $msg = __('The certificate CANNOT be renewed');
            if ($jsonReply) {
                $self->{json}->{success} = 0;
                $self->{json}->{message} = $msg;
            } else {
                throw EBox::Exceptions::External($msg);
            }
        } else {
            my $msg;
            if ($isCACert) {
                $msg = __("The new CA certificate has been renewed") if ($isCACert);
            } else {
                $msg = __("The certificate has been renewed");
            }

            if ($jsonReply) {
                $self->{json}->{success} = 1;
                $self->{json}->{msg} = $msg;
                my $cert = $ca->getCertificateMetadata(cn => $commonName, dateAsString => 1);
                delete $cert->{dn};
                $self->{json}->{certificate} = $cert;
            } else {
                $self->setMsg($msg);
                my $request = $self->request();
                my $parameters = $request->parameters();
                $parameters->clear();
            }
        }
    }
}

1;
