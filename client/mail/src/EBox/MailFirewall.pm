# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::MailFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Mail;
use EBox::Gettext;
use EBox::Validate qw( :all );


my %portByService = (
		     'active' => 25,
		     'pop'    => 110,
		     'imap'   => 143,
		     # filter service port can change so we add it in the constructor
		    );


my %servicesWithSsl = (
		       pop  =>  {
				 port => 995,
				 getter => 'sslPop',
				},
		       
		       imap => { 
				port => 993,
				getter => 'sslImap',
			       },
		      );

sub new 
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);

	# retrieve port for filter service
	my $mail = EBox::Global->modInstance('mail');
	$portByService{filter} = $mail->fwport();

        bless($self, $class);
        return $self;
}

sub input
{
	my $self = shift;
	my @rules = ();
	
	my $mail = EBox::Global->modInstance('mail');

	my $net = EBox::Global->modInstance('network');
	my @ifaces = @{ $net->InternalIfaces() };
	foreach my $ifc (@ifaces) {
	  foreach my $service (keys %portByService) {
	    $mail->service($service) or
	      next;

	    push @rules, $self->serviceRules($mail, $service, $ifc);
	    push @rules, $self->sslServiceRules($mail, $service, $ifc);
	  }
	}

	
	return \@rules;
}





sub serviceRules
{
  my ($self, $mail, $service, $ifc) = @_;


  my $r = "";
  if($service eq 'filter') {
    $r .= "-s ".$mail->ipfilter." ";
  }

  $r .= "-m state --state NEW -i $ifc  ".
    "-p tcp --dport ".$portByService{$service}." -j ACCEPT";
	  
  return ($r);
}


sub sslServiceRules
{
  my ($self, $mail, $service, $ifc) = @_;

  exists $servicesWithSsl{$service} or
    return;

  my $getter = $servicesWithSsl{$service}->{getter};
  my $state = $mail->$getter();
  if ($state eq 'no') {
    # ssl service not allowed
    return ();
  }
  
  my $port = $servicesWithSsl{$service}->{port};

  my $r = "";
  if($service eq 'filter') {
    $r .= "-s ".$mail->ipfilter." ";
  }

  $r .= "-m state --state NEW -i $ifc  ".
    "-p tcp --dport ". $port ." -j ACCEPT";
	  
  return ($r);
}

sub externalInput
{
  my ($self) = @_;
  my @rules = ();

  my $mail = EBox::Global->modInstance('mail');
  if ($mail->service) {
    push @rules, '-m state --state NEW -p tcp --dport 25 -j ACCEPT';
  }


  return \@rules;
}

sub output
{
	my $self = shift;
	my @rules = ();
	
	my $net = EBox::Global->modInstance('network');
	my $mail = EBox::Global->modInstance('mail');
	
	my @ifaces = @{$net->InternalIfaces()};
	my @exifaces = @{$net->ExternalIfaces()};
	my $port = $mail->portfilter();
	my $ipfilter = $mail->ipfilter();
	my @conf = ();
	my $r;

	if (($mail->service()) and ($mail->service('filter'))) {
		foreach my $ifc (@ifaces) {
			@conf = @{$net->ifaceAddresses($ifc)};

			foreach my $c (@conf) {
				if(isIPInNetwork($$c{'address'}, 
							$$c{'netmask'},
							$mail->ipfilter())) {
					
					$r = "-d $ipfilter -m state --state NEW -o $ifc ".
						"-p tcp --dport $port -j ACCEPT";

					push(@rules, $r);
				}
			}
		}
	}
	if ($mail->service()) {
		$r = "-m state --state NEW -p tcp --dport 25 -j ACCEPT";
		push(@rules, $r);
	}
	
	return \@rules;
}

1;
