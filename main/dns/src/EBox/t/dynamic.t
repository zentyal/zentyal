# This tests will test the configuration for a dynamic update
use EBox;
use EBox::Global;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;

use Net::DNS;
use Net::DNS::Resolver;
use Net::DNS::Update;

EBox::init();
my $dns = EBox::Global->modInstance('dns');

my $domainMod = $dns->model('DomainTable');
my $domainRow = $domainMod->find(dynamic => 1);

exit unless defined($domainRow);

# Add host
my $updatePkt = new Net::DNS::Update($domainRow->valueByName('domain'), 'IN');
my $fullHost = 'foo.' . $domainRow->valueByName('domain');
$updatePkt->push(pre => nxdomain($fullHost));
# Add A record TTL = 86400 s
$updatePkt->push(update => rr_add("$fullHost A 2.1.1.2"));
$updatePkt->sign_tsig($domainRow->valueByName('domain'), $domainRow->valueByName('tsigKey'));

# Resolver
my $resolver = new Net::DNS::Resolver(nameservers => [ '127.0.0.1'], recurse => 0);

my $reply = $resolver->send($updatePkt);
if ( $reply ) {
    my $replyCode = $reply->header()->rcode();
    if ( $replyCode eq 'YXDOMAIN' ) {
        throw EBox::Exceptions::DataExists(data => "RR",
                                           value => "foo");
    } elsif ( $replyCode ne 'NOERROR' ) {
        throw EBox::Exceptions::Internal($resolver->errorstring());
    }
} else {
    throw EBox::Exceptions::Internal($resolver->errorstring());
}
print "foo host added correctly to " . $domainRow->valueByName('domain') . "\n";
