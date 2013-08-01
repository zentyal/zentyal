use strict;
use warnings;

package EBox::LDB::IdMapDb;

use constant PRIVATE_DIR => '/opt/samba4/private/';
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

    $self->deleteMapping($sid, 1);

    my $ldif = "dn: CN=$sid\n" .
               "changetype: add\n" .
               "xidNumber: $uidNumber\n" .
               "objectSid: $sid\n" .
               "objectClass: sidMap\n" .
               "type: $type\n" .
               "cn: $sid\n";
    EBox::debug("Mapping XID '$uidNumber' to '$sid'");
    EBox::Sudo::root("echo '$ldif' | ldbmodify -H $self->{file}");
}

sub deleteMapping
{
    my ($self, $sid, $silent) = @_;

    my $ldif = "dn: CN=$sid\n" .
               "changetype: delete\n";
    if ($silent) {
        EBox::Sudo::silentRoot("echo '$ldif' | ldbmodify -H $self->{file}");
    } else {
        EBox::debug("Unmapping XID '$sid'");
        EBox::Sudo::root("echo '$ldif' | ldbmodify -H $self->{file}");
    }
}

sub getXidNumberBySID
{
    my ($self, $sid) = @_;

    EBox::debug("Searching for the XID of '$sid'");
    my $output = EBox::Sudo::root("ldbsearch -H $self->{file} \"(&(objectClass=sidMap)(cn=$sid))\" | grep -v ^GENSEC");
    my $ldifBuffer = join ('', @{$output});
    EBox::debug($ldifBuffer);

    my $fd;
    open $fd, '<', \$ldifBuffer;

    my $xid = undef;
    my $ldif = Net::LDAP::LDIF->new($fd);
    if (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        if ($ldif->error()) {
            EBox::debug("Error msg: " . $ldif->error());
            EBox::debug("Error lines:\n" . $ldif->error_lines());
        } if (not $ldif->eof()) {
            EBox::debug("Got more than one entry!");
        } else {
            $xid = $entry->get_value('xidNumber');
        }
    }
    $ldif->done();
    close $fd;

    return $xid
}

1;
