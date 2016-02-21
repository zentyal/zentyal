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

package EBox::CA::CGI::Index;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use TryCatch;

# Method: new
#
#       Constructor for Index CGI
#
# Returns:
#
#       Index - The object recently created
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('title'  => __('Certification Authority'),
                                  @_);

    bless($self, $class);

    return $self;
}

# Method: masonParameters
#
# Overrides:
#
#     <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');

    # Check if the CA infrastructure has been created
    my @array = ();

    if ( $ca->isCreated() ) {
        $self->{'template'} = "ca/index.mas";
        try {
            # Update CA DB prior to displaying certificates
            $ca->updateDB();
        } catch ($ex) {
            $self->{template} = '/error.mas';
            return [error => "$ex"];
        }

        push( @array, 'certs' => $ca->listCertificates() );

        # Check if a new CA certificate is needed (because of revokation from RevokeCertificate)
        my $currentState;
        try {
            $currentState  = $ca->currentCACertificateState();
        } catch ($ex) {
            $self->{template} = '/error.mas';
            return [error => "$ex"];
        }

        if ( $currentState =~ m/[RE]/) {
            push( @array, 'caNeeded' => 1);
        } else {
            push( @array, 'passRequired' => $ca->passwordRequired() );
            push( @array, 'caExpirationDays' => $ca->caExpirationDays() );
        }
    } else {
        $self->{'template'} = "ca/createCA.mas";
    }

    return \@array;
}

1;
