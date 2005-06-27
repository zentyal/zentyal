# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Ldap;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Constant;
use Net::LDAP::Message;
use Net::LDAP::Search;
use Net::LDAP::LDIF;
use Net::LDAP qw(LDAP_SUCCESS);

use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use Data::Dumper;
use Encode qw( :all );

use Error qw(:try);

use constant DN            => "dc=ebox";
use constant LDAPI         => "ldapi://%2fvar%2frun%2fldapi";
use constant SLAPDCONFFILE => "/etc/ldap/slapd.conf";
use constant ROOTDN        => 'cn=admin,' . DN;

sub new {
	my $class = shift;
	
	my $self = {};
	$self->{ldap} = undef;
	bless($self, $class);
	return $self;
}

# Method: ldapCon 
#
#       Returns the Net::LDAP connection
#       
# Returns:    
#               
#       An object of class Net::LDAP whose connection has already bound       
#
# Exceptions: 
#               
#       Internal - If connection can't be created
sub ldapCon {
	my $self = shift;

	return $self->{ldap} if ($self->{ldap});

	$self->{ldap} = Net::LDAP->new (LDAPI)
			or throw EBox::Exceptions::Internal( 
					"Can't create ldapi connection");
	$self->{ldap}->bind(ROOTDN, password => getPassword());

	return $self->{ldap};
}

# Method: getPassword 
#
#       Returns the password used to connect to the LDAP directory
#       
# Returns:    
#               
#       string - password
#
# Exceptions: 
#               
#       Internal - If password can't be read
sub getPassword {

	my $path = EBox::Config->conf . "/ebox-ldap.passwd";
        open(PASSWD, $path) or
                throw EBox::Exceptions::Internal("Could not open $path to " .
						 "get ldap password");

        my $pwd = <PASSWD>;
        close(PASSWD);

        $pwd =~ s/[\n\r]//g;

	return $pwd;
}


# Method: dn
#
#       Returns the dn
#       
# Returns:    
#               
#       string - dn
#
sub dn {
	return DN;
}

# Method: rootDn
#
#       Returns the dn of the priviliged user
#       
# Returns:    
#               
#       string - rootdn
#
sub rootDn {
	return ROOTDN
}

# Method: rootPw
#
#       Returns the password of the priviliged user
#       
# Returns:    
#               
#       string - password
#
sub rootPw {
	return getPassword();
}

# Method: slapdConfFile
#
#       Returns the location of the slapd's configuration file
#       
# Returns:    
#               
#       string - location
#
sub slapdConfFile {
	return SLAPDCONFFILE;
}

# Method: ldapConf
#
#       Returns the current configuration for LDAP: 'dn', 'ldapi', 'rootdn'
#       
# Returns:    
#               
#     hash ref  - holding the keys 'dn', 'ldapi' and 'rootdn' 
#
sub ldapConf {
	shift;
	
	my $conf = {
		     'dn'     => DN,
		     'ldapi'  => LDAPI,
		     'rootdn' => ROOTDN,
		   };
	return $conf;
}

# Method: search
#
#       Performs a search in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#	args - arguments to pass to Net::LDAP->search()
#               
# Exceptions:
#
#	Internal - If there is an error during the search
sub search($$) # (args)
{
	my $self = shift;
	my $args = shift;

	$self->ldapCon;	
	my $result = $self->{ldap}->search(%{$args});
	_errorOnLdap($result, $args);
	return _utf8Attrs($result);
	
}

# Method: modify
#
#       Performs  a  modification in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#	dn - dn where to perform the modification 
#	args - parameters to pass to Net::LDAP->modify()
#               
# Exceptions:
#
#	Internal - If there is an error during the search
sub modify($$) {
	my $self = shift;
	my $dn   = shift;
	my $args = shift;

	$self->ldapCon;	
	my $result = $self->{ldap}->modify($dn, %{$args});
	_errorOnLdap($result, $args);
	return $result;

}

# Method: delete
#
#       Performs  a deletion  in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#	dn - dn to delete 
#               
# Exceptions:
#
#	Internal - If there is an error during the search
sub delete($$) {
	my $self = shift;
	my $dn   = shift;
	
	$self->ldapCon;	
	my $result =  $self->{ldap}->delete($dn);
	_errorOnLdap($result, $dn);
	return $result;

}

# Method: add
#
#       Adds an object or attributes  in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#	dn - dn to add
#	args - parameters to pass to Net::LDAP->add()
#               
# Exceptions:
#
#	Internal - If there is an error during the search

sub add($$) {
	my $self = shift;
	my $dn   = shift;
	my $args = shift;
	
	$self->ldapCon;	
	my $result =  $self->{ldap}->add($dn, %{$args});
	_errorOnLdap($result, $args);
	return $result;
}


sub _errorOnLdap($;$) 
{
        my $result = shift;
        my $args   = shift;

        my  @frames = caller (2);
        if ($result->is_error){
                if ($args) {
			use Data::Dumper;
			print STDERR Dumper($args);
                }
                throw EBox::Exceptions::Internal("Unknown error at " .
						$frames[3] . " " .
						$result->error);
        }
}

# Workaround to mark strings returned from ldap as utf8 strings
sub _utf8Attrs # (result)
{
        my $result = shift;

        my @entries = $result->entries;
        foreach my $attr (@{$entries[0]->{'asn'}->{'attributes'}}) {
                my @vals = @{$attr->{vals}};
                next unless (@vals);
                my @utfvals;
                foreach my $val (@vals) {
                        _utf8_on($val);
                        push @utfvals, $val;
                }
                $attr->{vals} = \@utfvals;
        }
        return $result;
}

1;
