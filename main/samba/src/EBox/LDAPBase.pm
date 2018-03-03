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

package EBox::LDAPBase;

use EBox::Exceptions::LDAP;
use EBox::Exceptions::NotImplemented;
use EBox::Gettext;

use TryCatch;
use Net::LDAP::Constant qw(LDAP_SUCCESS LDAP_NO_SUCH_OBJECT LDAP_CONTROL_PAGED);
use Net::LDAP::Control::Paged;
use POSIX;

sub _new_instance
{
    my $class = shift;

    my $self = {};
    $self->{ldap} = undef;
    bless($self, $class);
    return $self;
}

# Method: connection
#
#   Return the Net::LDAP connection used by the module
#
# Exceptions:
#
#   Internal - If connection can't be created
#
sub connection
{
    throw EBox::Exceptions::NotImplemented();
}


# Method: dn
#
#       Returns the base DN (Distinguished Name)
#
# Returns:
#
#       string - DN
#
sub dn
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: clearConn
#
#       Closes LDAP connection and clears DN cached value
#
sub clearConn
{
    my ($self) = @_;

    if (defined $self->{ldap}) {
        $self->{ldap}->disconnect();
    }
    delete $self->{dn};
    delete $self->{ldap};
}

# Method: search
#
#       Performs a search in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       args - arguments to pass to Net::LDAP->search()
#
# Returns:
#   Net::LDAP::Search object with the results of the search
#
# Exceptions:
#
#       EBox::Exceptions::LDAP - If there is an error during the search
sub search # (args)
{
    my ($self, $args) = @_;

    $self->connection();
    #FIXME: this was added to deal with a problem where an object wouldn't be
    #returned if attributes were required but objectclass wasn't required too
    #it's apparently working now, so it's commented, remove it if it works
#    if (exists $args->{attrs}) {
#        my %attrs = map { $_ => 1 } @{$args->{attrs}};
#        unless (exists $attrs{objectClass}) {
#                push (@{$args->{attrs}}, 'objectClass');
#        }
#    }
    my $result = $self->{ldap}->search(%{$args});
    unless ($result->code() == LDAP_NO_SUCH_OBJECT) {
        $self->_errorOnLdap($result, $args);
    }
    return $result;
}

# Method: pagedSearch
#
#  Performs a paginated search in the LDAP directory
#
#  Parameters
#       args - arguments to pass to Net::LDAP->search() .
#       pageSize - number of result for page (default: 500)
#
#  Returns:
#    reference to a list of Net::LDAP::Entry containing all the entries found
#
#   Limitations:
#     args shoud not contain already a Paged control. It can contain other controls
#
# Exceptions:
#       EBox::Exceptions::LDAP - If there is an error during the search
#
sub pagedSearch
{
    my ($self, $args, $pageSize) = @_;
    if (not $pageSize) {
        $pageSize = 500;
    }

    my $page = Net::LDAP::Control::Paged->new( size => $pageSize );
    if (not $args->{control}) {
        $args->{control} = [];
    }
    push @{ $args->{control} }, $page;

    my $cookie;
    my @entries = ();
    while (1) {
        my $result = $self->search($args);
        if ($result->code() ne LDAP_SUCCESS) {
            last;
        }

        push @entries, $result->entries();

        my ($resp) = $result->control( LDAP_CONTROL_PAGED );
        if (not $resp) {
            # not found page control
            last;
        }
        $cookie = $resp->cookie;
        if (not $cookie) {
            # finished
            last;
        }

        $page->cookie($cookie);
    }

    if ($cookie) {
        # We had an abnormal exit, so let the server know we do not want any more
        $page->cookie($cookie);
        $page->size(0);
        $self->search($args)
    }

    return \@entries;
}

# Method: existsDN
#
#       checks if a give DN exists in the directory
#
# Parameters:
#
#       dn - dn to check
#
#  Returns:
#     - boolean
#
# Exceptions:
#
#       EBox::Exceptions::LDAP - If there is an error during the search
sub existsDN
{
    my ($self, $dn) = @_;

    my $ldap = $self->connection();
    my @searchArgs = (
        base => $dn,
        scope => 'base',
        filter => "(objectclass=*)"
       );
    my $result = $ldap->search(@searchArgs);
    if ($result->is_error()) {
        if ($result->code() == Net::LDAP::Constant::LDAP_NO_SUCH_OBJECT()) {
            # base does not exists
            return 0;
        } else {
            $self->_errorOnLdap($result, {@searchArgs});
        }
    }

    return 1;
}

# Method: modify
#
#       Performs a modification in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       dn - dn where to perform the modification
#       args - parameters to pass to Net::LDAP->modify()
#
# Exceptions:
#
#       Internal - If there is an error during the search
sub modify
{
    my ($self, $dn, $args) = @_;

    $self->connection();
    my $result = $self->{ldap}->modify($dn, %{$args});
    $self->_errorOnLdap($result, $args, dn => $dn);
    return $result;
}

# Method: delete
#
#       Performs  a deletion  in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       dn - dn to delete
#
# Exceptions:
#
#       Internal - If there is an error during the search
sub delete
{
    my ($self, $dn) = @_;

    $self->connection();
    my $result =  $self->{ldap}->delete($dn);
    $self->_errorOnLdap($result, $dn);
    return $result;
}

# Method: add
#
#       Adds an object or attributes  in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       dn - dn to add
#       args - parameters to pass to Net::LDAP->add()
#
# Exceptions:
#
#       Internal - If there is an error during the search

sub add # (dn, args)
{
    my ($self, $dn, $args) = @_;

    $self->connection();
    my $result =  $self->{ldap}->add($dn, %{$args});
    $self->_errorOnLdap($result, $args, dn => $dn);
    return $result;
}

# Method: delObjectclass
#
#       Remove an objectclass from an object an all its associated attributes
#
# Parameters:
#
#       dn - object's dn
#       objectclass - objectclass
#
# Exceptions:
#
#       Internal - If there is an error during the search
sub delObjectclass # (dn, objectclass);
{
    my ($self, $dn, $objectclass) = @_;

    my $schema = $self->connection()->schema();
    my $searchArgs = {
        base => $dn,
        scope => 'base',
        filter => "(objectclass=$objectclass)"
       };
    my $msg = $self->search($searchArgs);
    $self->_errorOnLdap($msg, $searchArgs);
    return unless ($msg->entries > 0);

    my %attrexist = map {$_ => 1} $msg->pop_entry->attributes;
    my $attrSearchArgs = {
        base => $dn,
        scope => 'base',
        attrs => ['objectClass'],
        filter => '(objectclass=*)'
       };
    $msg = $self->search($attrSearchArgs);
    $self->_errorOnLdap($msg, $attrSearchArgs);
    my %attrs;
    for my $oc (grep(!/^$objectclass$/, $msg->entry->get_value('objectclass'))){
        # get objectclass attributes
        my @ocattrs =  map {
            $_->{name}
        }  ($schema->must($oc), $schema->may($oc));

        # mark objectclass attributes as seen
        foreach (@ocattrs) {
            $attrs{$_ } = 1;
        }
    }

    # get the attributes of the object class which will be deleted
    my @objectAttrs = map {
        $_->{name}
    }  ($schema->must($objectclass), $schema->may($objectclass));

    my %attr2del;
    for my $attr (@objectAttrs) {
        # Skip if the attribute belongs to another objectclass
        next if (exists $attrs{$attr});
        # Skip if the attribute is not stored in the object
        next unless (exists $attrexist{$attr});
        $attr2del{$attr} = [];
    }

    my $result;
    if (%attr2del) {
        my $deleteArgs = [ objectclass => $objectclass, %attr2del ];
        $result = $self->modify($dn, { changes =>
                [delete => $deleteArgs] });
        $self->_errorOnLdap($msg, $deleteArgs);
    } else {
        my $deleteArgs = [ objectclass => $objectclass ];
        $result = $self->modify($dn, { changes =>
                [delete => $deleteArgs] });
        $self->_errorOnLdap($msg, $deleteArgs);
    }
    return $result;
}

# Method: modifyAttribute
#
#       Modify an attribute from a given dn
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to change
#       value - new value
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub modifyAttribute # (dn, attribute, value);
{
    my ($self, $dn, $attribute, $value) = @_;

    my %attrs = ( changes => [ replace => [ $attribute => $value ] ]);
    $self->modify($dn, \%attrs );
}

# Method: setAttribute
#
#       Modify the value of an attribute from a given dn if it exists
#       Add the attribute with the given value if it doesn't exist
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to add/change
#       value - new value
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub setAttribute # (dn, attribute, value);
{
    my ($self, $dn, $attribute, $value) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);
    my $action = $result->count > 0 ? 'replace' : 'add';

    my %attrs = ( changes => [ $action => [ $attribute => $value ] ]);
    $self->modify($dn, \%attrs);
}

# Method: delAttribute
#
#       Delete an attribute from a given dn if it exists
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to delete
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub delAttribute # (dn, attribute);
{
    my ($self, $dn, $attribute, $value) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);
    if ($result->count > 0) {
        my %attrs = ( changes => [ delete => [ $attribute => [] ] ]);
        $self->modify($dn, \%attrs);
    }
}

# Method: getAttribute
#
#       Get the value for the given attribute.
#       If there are more than one, the first is returned.
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to get its value
#
# Returns:
#       string - attribute value if present
#       undef  - if attribute not present
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub getAttribute # (dn, attribute);
{
    my ($self, $dn, $attribute) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);

    return undef unless ($result->count > 0);

    return $result->entry(0)->get_value($attribute);
}

# Method: isObjectClass
#
#      check if a object is member of a given objectclass
#
# Parameters:
#          dn          - the object's dn
#          objectclass - the name of the objectclass
#
#  Returns:
#    boolean - wether the object is member of the objectclass or not
sub isObjectClass
{
    my ($self, $dn, $objectClass) = @_;

    my %attrs = (
            base   => $dn,
            filter => "(objectclass=$objectClass)",
            attrs  => [ 'objectClass'],
            scope  => 'base'
            );

    my $result = $self->search(\%attrs);

    if ($result->count ==  1) {
        return 1;
    }

    return undef;
}

# Method: objectClasses
#
#      return the object classes of an object
#
# Parameters:
#          dn          - the object's dn
#
#  Returns:
#    array - containing the object classes
sub objectClasses
{
    my ($self, $dn) = @_;

    my %attrs = (
            base   => $dn,
            filter => "(objectclass=*)",
            attrs  => [ 'objectClass'],
            scope  => 'base'
            );

    my $result = $self->search(\%attrs);

    return [ $result->pop_entry()->get_value('objectClass') ];
}

# Method: lastModificationTime
#
#     Get the last modification time for the directory
#
# Parameters:
#
#     fromTimestamp - String from timestamp to start the query from to
#                     speed up the query. If the value is greater than
#                     the LDAP last modification time, then it returns zero
#                     *Optional* Default value: undef
#
# Returns:
#
#     Int - the timestamp in seconds since epoch
#
# Example:
#
#     $ldap->lastModificationTime('20091204132422.0Z') => 1259955547
#
sub lastModificationTime
{
    my ($self, $fromTimestamp) = @_;

    my $filter = '(objectclass=*)';
    if (defined($fromTimestamp)) {
        $filter = "(&(objectclass=*)(modifyTimestamp>=$fromTimestamp))";
    }

    my $res = $self->search({base => $self->dn(), attrs => [ 'modifyTimestamp' ],
                             filter => $filter });
    # Order alphanumerically and the latest is the one whose timestamp
    # is the last one
    my @sortedEntries = $res->sorted('modifyTimestamp');
    if ( scalar(@sortedEntries) == 0) {
        # fromTimestamp given is greater than the current time, so we return 0
        return 0;
    }
    my $lastStamp = $sortedEntries[-1]->get_value('modifyTimestamp');

    # Convert to seconds since epoch lastStamp example: 20140917122427.0Z
    my ($year, $month, $day, $h, $m, $s) =
      $lastStamp =~ /^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/;
    return POSIX::mktime( $s, $m, $h, $day, $month -1, $year - 1900 );

}
# Method: _errorOnLdap
#
#   Check the result for errors
#
sub _errorOnLdap
{
    my ($class, $result, $args, @addToArgs) = @_;

    if ($result->is_error()){
        while (my ($name, $value) = splice(@addToArgs, 0 ,2) ) {
            $args->{$name} = $value;
        }
        throw EBox::Exceptions::LDAP(result => $result, opArgs => $args);
    }
}

# Method: url
#
#  Return the URL or parameter to create a connection with this LDAP
sub url
{
    throw EBox::Exceptions::NotImplemented();
}

sub safeConnect
{
    throw EBox::Exceptions::NotImplemented();
}

sub connectWithKerberos
{
    throw EBox::Exceptions::NotImplemented();
}

1;
