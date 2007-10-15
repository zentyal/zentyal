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

package EBox::Squid::Model::DomainFilter;

# Class:
#
#    EBox::Squid::Model::DomainFilter
#
#
#   It subclasses <EBox::Model::DataTable>
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Squid::Types::Policy;
use EBox::Types::Text;
use EBox::Validate;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::DomainFilter> - the recently
#       created model
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless $self, $class;
      return $self;

  }

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name          - <EBox::Types::Text>
#       description   - <EBox::Types::Text>
#       configuration - <EBox::Types::Union>. It could have one of the following:
#                     - model - <EBox::Types::HasMany>
#                     - link  - <EBox::Types::Link>
#                     - none  - <EBox::Types::Union::Text>
#       enabled       - <EBox::Types::Boolean>
#
#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
#
sub _table
  {
    my $warnMsg = q{The domain filter needs a 'filter' policy to take effect};

      my @tableHeader =
        (
         new EBox::Types::Text(
                               fieldName     => 'domain',
                               printableName => __('Domain'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
         new EBox::Squid::Types::Policy(
                               fieldName     => 'policy',
                               printableName => __('Policy'),
			       defaultValue  => 'filter',
                              ),
        );

      my $dataTable =
        {
         tableName          => 'DomainFilter',
         printableTableName => __('Configure allowed internet domains'),
	 modelDomain        => 'Squid',
	 'defaultController' => '/ebox/Squid/Controller/DomainFilter',
	 'defaultActions' =>
	 [	
	  'add', 'del',
	  'editField',
	  'changeView'
	 ],
         tableDescription   => \@tableHeader,
         class              => 'dataTable',
         order              => 0,
         rowUnique          => 1,
         printableRowName   => __('internet domain'),
         help               => __('Allow/Deny the HTTP traffic from/to the listed internet domains.'),
	 messages           => {
				add => $warnMsg,
				del => $warnMsg,
				update => $warnMsg,
				moveUp => $warnMsg,
				moveDown => $warnMsg,
			       },

	};

  }


sub validateTypedRow
{
  my ($self, $action, $params_r) = @_;

  my $domain = $params_r->{domain}->value();

  if ($domain =~ m{^www\.}) {
    throw EBox::Exceptions::InvalidData(
					data => __('Domain'),
					value => $domain,
					advice => __('You must not prefix the domain with www.'),
				       );
  }

  EBox::Validate::checkDomainName($domain);
}


# Function: bannedDomains
#
#	Fetch the banned extensions
#
# Returns:
#
# 	Array ref - containing the extensions
sub banned
{
  my ($self) = @_;
  return $self->_domainsByPolicy('deny');
}


# Function: allowedDomains
#
#	Fetch the allowed extensions
#
# Returns:
#
# 	Array ref - containing the extensions
sub allowed
{
  my ($self) = @_;
  return $self->_domainsByPolicy('allow');
}



sub _domainsByPolicy
{
  my ($self, $policy) = @_;

  my @domains = map {
    my $values = $_->{plainValueHash};

    if ($values->{policy} eq $policy)  {
      ($values->{domain})
    }
    else {
      ()
    }
    

  } @{ $self->rows() };


  return \@domains;
}

1;

