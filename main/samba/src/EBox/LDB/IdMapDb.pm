package EBox::LDB::IdMapDb;

use strict;
use warnings;

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
        file => PRIVATE_DIR . FILE
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
    my ($self, $sid, $type, $uidNumber) = @_;

    my $file = EBox::Config::tmp() . 'idmap.ldif';
    my $ldif = "dn: CN=$sid\n" .
               "changetype: add\n" .
               "xidNumber: $uidNumber\n" .
               "objectSid: $sid\n" .
               "objectClass: sidMap\n" .
               "type: $type\n" .
               "cn: $sid\n";
    EBox::debug("Mapping XID '$uidNumber' to '$sid'");
    EBox::Sudo::root("echo '$ldif' | ldbmodify -H $self->{file}");
    unlink $file;
}

sub deleteMapping
{
    my ($self, $sid) = @_;

    my $file = EBox::Config::tmp() . 'idmap.ldif';
    my $ldif = "dn: CN=$sid\n" .
               "changetype: delete\n";
    EBox::debug("Unmapping XID '$sid'");
    EBox::Sudo::root("echo '$ldif' | ldbmodify -H $self->{file}");
    unlink $file;
}

1;
