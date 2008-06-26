package EBox::OpenVPN::Server::ClientBundleGenerator::Test;
use base 'EBox::Test::Class';

#
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::MockObject;
use EBox::TestStubs;

use File::Slurp qw(read_file write_file);

use lib '../../../..';

use EBox::OpenVPN::Server::ClientBundleGenerator;

sub _fakeGetHtmlPageCmd
{
    my ($self, $fake) = @_;
    my $sub_r;

    if ((ref $fake) eq 'CODE' ) {
        $sub_r = $fake;
    }else {
        $sub_r = sub { return $fake  }
    }

    Test::MockObject->fake_module(
                                 'EBox::OpenVPN::Server::ClientBundleGenerator',
                                 _getHtmlPageCmd => $sub_r,);
}

sub _newFakeServer
{
    my ($localAddr) = @_;
    my $server = new Test::MockObject;
    $server->set_always('localAddress' => $localAddr);
}

my @fakeExternalIfaces = qw(eth0 eth2 eth13 eth22);
my %addressByFakeExternalIface = (
    eth0 =>  '10.45.23.1',
    eth2 => '34.12.55.12',

    eth13 => '20.16.23.12',

    eth22 => '121.34.12.22',
);

sub _fakeNetwork : Test(startup)
{
    EBox::TestStubs::fakeEBoxModule(
        name => 'network',
        subs => [
            ExternalIfaces => sub {
                return \@fakeExternalIfaces;
            },
            ifaceAddress => sub {
                my ($self, $iface) = @_;
                return$addressByFakeExternalIface{$iface};
            },
        ],
    );

}

sub _fakeTmp : Test(startup)
{
    my $fakeTmpDir = '/tmp/ebox.cleintbundlegenrator.test';

    system "rm -rf $fakeTmpDir";
    system "mkdir -p $fakeTmpDir";

    EBox::TestStubs::setEBoxConfigKeys(tmp => $fakeTmpDir);
}

sub getHtmlPageErrorTest : Test(6)
{
    my ($self) = @_;

    my %errorTypes = (
        'clear failure (external command has error code)' =>'/bin/false',

        'failure without error code, retrevied page is empty' =>sub {
            my ($file, $local) = @_;
            system "rm -rf $file";
            return "touch $file";
        },

        'page retrevied has bad data' =>sub {
            my ($file, $local) = @_;
            system "echo nonsense nonsense sasa sfda > $file";
            return "/bin/true";
        },
    );

    my $server = _newFakeServer;

    while (my ($desc, $fakeCmd) = each %errorTypes) {
        diag "Testig failure type: $desc";

        $self->_fakeGetHtmlPageCmd($fakeCmd);

        my $externalAddr_r;
        lives_ok {
            $externalAddr_r =
              EBox::OpenVPN::Server::ClientBundleGenerator->serversAddr(
                                                                       $server);
        }
'Checking that a  failure retrieving the ip information web page does not raises error';

        is_deeply $externalAddr_r, [],
"Checking wether a  failure in retrieving the ip page returns a empty list of server's address";

    }

}

sub serversAddrStraighTest : Test(8)
{

    my ($self) = @_;

    my $pageContentEth0 = <<END;
83.52.31.220 (ES-Spain) http://www.ippages.com Tue, 18 Sep 2007 09:53:17 UTC/GMT
(1 of 199 allowed today)
alternate access in XML format at: http://www.ippages.com/xml 
alternate access via SOAP at: http://www.ippages.com/soap/server.php 
alternate access via RSS feed at: http://www.ippages.com/rss.php 
alternate access in VoiceXML format at: http://www.ippages.com/voicexml 
END

    my $pageContentEth2 = <<END;
83.92.31.224 (ES-Spain) http://www.ippages.com Tue, 18 Sep 2007 09:53:17 UTC/GMT
(1 of 199 allowed today)
alternate access in XML format at: http://www.ippages.com/xml 
alternate access via SOAP at: http://www.ippages.com/soap/server.php 
alternate access via RSS feed at: http://www.ippages.com/rss.php 
alternate access in VoiceXML format at: http://www.ippages.com/voicexml 
END

    my $pageContentEth13 = "eth13 does not porive any external address";

    # eth22 is to check that we don't get duplicates
    my $pageContentEth22 = $pageContentEth2;

    my %contentByLocal = (
                        $addressByFakeExternalIface{eth0} => $pageContentEth0,
                        $addressByFakeExternalIface{eth2} => $pageContentEth2,
                        $addressByFakeExternalIface{eth13} => $pageContentEth13,
                        $addressByFakeExternalIface{eth22} => $pageContentEth22,
    );

    $self->_fakeGetHtmlPageCmd(
        sub {
            my ($file, $local) = @_;
            my $content = '';
            if (exists $contentByLocal{$local}) {
                $content = $contentByLocal{$local};
            }else {
                die "no mock content provided for local $local";
            }

            write_file($file, $content);

            return "/bin/true";
        },

    );

    my %addressesByListen = (
                   'all' => [sort qw(83.52.31.220 83.92.31.224)],
                   $addressByFakeExternalIface{eth0} => [qw(83.52.31.220)],
                   $addressByFakeExternalIface{eth2} => [sort qw(83.92.31.224)],
                   $addressByFakeExternalIface{eth13} => [],
    );

    while (my ($listen, $expectedAddress_r) = each %addressesByListen) {
        diag "Test for server listening in $listen addreses/s";

        my $server;
        if ($listen eq 'all' ) {
            $server = _newFakeServer();
        }else {
            $server = _newFakeServer($listen);
        }

        my $externalAddr_r;
        lives_ok {
            $externalAddr_r =
              EBox::OpenVPN::Server::ClientBundleGenerator->serversAddr(
                                                                       $server);
        }
        'Retreving external addresses of the server';

        $externalAddr_r = [sort @{$externalAddr_r}];
        is_deeply $externalAddr_r, $externalAddr_r,
          "Checking retrevied addresses";

    }

}

1;
