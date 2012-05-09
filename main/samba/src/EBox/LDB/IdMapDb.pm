package IdMapDb;

use Net::LDAP::LDIF;

use constant PRIVATE_DIR => '/var/lib/samba/private/';
use constant FILE        => 'idmap.ldb';

# Mappings for ID_TYPE_UID, ID_TYPE_GID and ID_TYPE_BOTH
use constant TYPE_UID  => 'ID_TYPE_UID';
use constant TYPE_GID  => 'ID_TYPE_GID';
use constant TYPE_BOTH => 'ID_TYPE_BOTH';

sub new
{
    my $class = shift;
    my $self = {
        file => PRIVATE_DIR . FILE;
        };
    bless ($self, $class);
    return $self;
}

# Method: setupNameMapping
#
#   Setup a mapping between a SID and a uidNumber
#
sub setupNameMapping
{
    my ($self, $dn, $type, $sid, $uidNumber) = @_;

    my $ldif = "dn: $dn\n" .
               "xidNumber: $uidNumber\n" .
               "objectSid: $sid\n" .
               "objectClass: sidMap\n" .
               "type: $type\n" .
               "cn: $sid\n";
    EBox::Sudo::root("echo '$ldif' | ldbadd -H $self->{file}");
}

1;
