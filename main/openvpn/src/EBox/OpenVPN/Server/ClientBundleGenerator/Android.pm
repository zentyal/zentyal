# Copyright (C) 2008-2012 eBox Technologies S.L.
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
#
package EBox::OpenVPN::Server::ClientBundleGenerator::Android;

# package:
use strict;
use warnings;
use File::Basename;
use EBox::Config;

use base 'EBox::OpenVPN::Server::ClientBundleGenerator';

sub bundleFilename
{
    my ($class, $serverName, $cn) = @_;

    my $filename = "$serverName-client";
    if ($cn) {
        $filename .= "-$cn";
    }
    return EBox::Config::downloads() . "$filename.ovpn";
}

sub createBundleCmds
{
    my ($class, $bundleFile, $tmpDir) = @_;

    my @filesInTmpDir = `ls '$tmpDir'`;
    chomp @filesInTmpDir;
    my $tmpfile = $tmpDir . "/tempbundle.ovpn";
    open (OUT,">$tmpfile") || EBox::error ("Error: Could not write on temp dir when creating bundle\n");
    for my $file (@filesInTmpDir) {
	if ($file eq "cacert.pem"){
	    EBox::debug ("Importing $file \n");
	    print OUT "<ca>\n";
	    print OUT my $cert= qx{/usr/bin/openssl x509  -in $tmpDir/$file  -ocsp_uri};
	    print OUT "</ca>\n";
	}
	else{
            if (qx{/usr/bin/openssl x509 -in $tmpDir/$file -ocsp_uri}){
	        EBox::debug ("Importing $file \n");
	        print OUT "<cert>\n";
                print OUT my $cert= qx{/usr/bin/openssl x509  -in $tmpDir/$file  -ocsp_uri};
                print OUT "</cert>\n";
	    }
	
	    else {
		if ( (fileparse($file,'\..*'))[2] eq ".pem"){
	            EBox::debug ("Importing $file \n");
	            print OUT "<key>\n";
	            print OUT qx{cat $tmpDir/$file};
	            print OUT "</key>\n";
	    	}
	        else {
	            EBox::debug ("Importing $file \n");
		    #FIXME: Find a cleaner way of removing certificate lines
		    open (IN,"<$tmpDir/$file")  || EBox::error ("Error: Could not write on temp dir when reading temporary config file");
	            while (my $line=<IN>) {
	    	        if ($line =~ /^ca   \"|^cert \"|^key  \"/){
			    print OUT "";
			}
			else {
			    print OUT $line;
			}
   		    }
	            close (IN);
		}
	    }
        }		
    }
    close (OUT);
    return ("cat  $tmpDir/tempbundle.ovpn > '$bundleFile'");
}

sub confFileExtension
{
    my ($class) = @_;
    return '.conf';
}

sub confFileExtraParameters
{
    my ($class) = @_;
    return ( userAndGroup => [qw(nobody nogroup)]);
}

1;
