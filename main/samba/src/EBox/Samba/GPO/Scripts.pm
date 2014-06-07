 # Copyright (C) 2013 Zentyal S.L.
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

#
# Class: EBox::Samba::GPO::Scripts
#
#   This is the base class for GPO: Scripts Extension Encoding, documented
#   in MS-GPOSCR (http://msdn.microsoft.com/en-us/library/cc232812.aspx)
#

package EBox::Samba::GPO::Scripts;

use base 'EBox::Samba::GPO::Extension';

use EBox::Gettext;
use EBox::Samba::SmbClient;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use Parse::RecDescent;
use Encode qw(encode decode);

# Constant: GRAMMAR_SCRIPTS_INI
#
#   This is the grammar to parse the file scripts.ini
#   Documented in section 2.2.2
#
#   The output is a data structure representing the file content:
#
#       {
#           Logon =>    {
#                           0 =>    {
#                                       CmdLine => 'script1.cmd',
#                                       Parameters => '-foo -bar',
#                                   }
#                           1 =>    {
#                                       CmdLine => 'script2.cmd',
#                                       Parameters => '-foo',
#                                   }
#                       }
#           Logoff =>   {
#                           0 =>    {
#                                       CmdLine => 'script1.cmd',
#                                       Parameters => '-foo -bar',
#                                   }
#                           1 =>    {
#                                       CmdLine => 'script2.cmd',
#                                       Parameters => '-foo',
#                                   }
#                       }
#       }
#
use constant GRAMMAR_SCRIPTS_INI => q{
IniFile:    WhiteSpace Sections WhiteSpace /\Z/
            { $return = $item[2] }
Sections:   Section(s?)
            {
                my $ret = {};
                foreach my $hash (@{$item[1]}) {
                    foreach my $key (keys %{$hash}) {
                        $ret->{$key} = $hash->{$key};
                    }
                }
                $return = $ret;
            }

WhiteSpaceClass:    "\n" | "\r" | "\t" | " "
WhiteSpace:         WhiteSpaceClass(s?)
SpaceDelimiter:     WhiteSpaceClass(s)

Section:        SectionHeader Keys[header => $item{SectionHeader}]
SectionHeader:  WhiteSpace "[" SectionName "]" SpaceDelimiter
                { $return = $item[3] }
SectionName:    TokLogon | TokLogoff | TokStartup | TokShutdown

Keys:   Key(s)
        {
            my $ret = {};
            my $header = $arg{header};
            $ret->{$header} = {};
            foreach my $hash (@{$item[1]}) {
                $ret->{$header}->{$hash->{index}}->{$hash->{key}} =
                    $hash->{value};
            }
            $return = $ret;
        }
Key:    TokKey TokIs TokValue
        {
            my ($index, $key) = ($item{TokKey} =~ m/(\d+)(.+)/);
            my $value = $item{TokValue};
            $return = {
                index => $index,
                key => $key,
                value => $value
            };
        }

TokKey:     WhiteSpace /\w+/
            { $return = $item[2] }
TokIs:      WhiteSpace '='
TokValue:   /[^\r\n]*/ SpaceDelimiter
            { $return = $item[1] }

TokLogon:       WhiteSpace 'Logon' WhiteSpace
                { $return = $item[2] }
TokLogoff:      WhiteSpace 'Logoff' WhiteSpace
                { $return = $item[2] }
TokStartup:     WhiteSpace 'Startup' WhiteSpace
                { $return = $item[2] }
TokShutdown:    WhiteSpace 'Shutdown' WhiteSpace
                { $return = $item[2] }

startrule:  IniFile
            { $return = $item[1] }
};

use constant GRAMMAR_PSSCRIPTS_INI => q{
IniFile:    WhiteSpace Sections WhiteSpace /\Z/
            { $return = $item[2] }
Sections:   Section(s?)
            {
                my $ret = {};
                foreach my $hash (@{$item[1]}) {
                    foreach my $key (keys %{$hash}) {
                        $ret->{$key} = $hash->{$key};
                    }
                }
                $return = $ret;
            }

WhiteSpaceClass:    "\n" | "\r" | "\t" | " "
WhiteSpace:         WhiteSpaceClass(s?)
SpaceDelimiter:     WhiteSpaceClass(s)

Section:        SectionHeader Keys[header => $item{SectionHeader}]
SectionHeader:  WhiteSpace "[" SectionName "]" SpaceDelimiter
                { $return = $item[3] }
SectionName:    TokLogon | TokLogoff | TokStartup | TokShutdown |
                TokScriptsConfig

Keys:   Key(s)
        {
            my $ret = {};
            my $header = $arg{header};
            $ret->{$header} = {};
            foreach my $hash (@{$item[1]}) {
                $ret->{$header}->{$hash->{index}}->{$hash->{key}} =
                    $hash->{value};
            }
            $return = $ret;
        }
Key:    TokKey TokIs TokValue
        {
            my ($index, $key) = ($item{TokKey} =~ m/(\d+)(.+)/);
            my $value = $item{TokValue};
            $return = {
                index => $index,
                key => $key,
                value => $value
            };
        }

TokKey:     WhiteSpace /\w+/
            { $return = $item[2] }
TokIs:      WhiteSpace '='
TokValue:   /[^\r\n]*/ SpaceDelimiter
            { $return = $item[1] }

TokLogon:           WhiteSpace 'Logon' WhiteSpace
                    { $return = $item[2] }
TokLogoff:          WhiteSpace 'Logoff' WhiteSpace
                    { $return = $item[2] }
TokStartup:         WhiteSpace 'Startup' WhiteSpace
                    { $return = $item[2] }
TokShutdown:        WhiteSpace 'Shutdown' WhiteSpace
                    { $return = $item[2] }
TokScriptsConfig:   WhiteSpace 'ScriptsConfig' WhiteSpace
                    { $return = $item[2] }
startrule:  IniFile
            { $return = $item[1] }
};

# Method: _scope
#
#   Returns the scope of the extension ('USER' for user scope, 'MACHINE' for
#   computer scope). Must be implemented by subclasses
#
sub _scope
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented();
}

# Method: _parserScriptsIni
#
#   Returns the parser for scripts.ini file
#
sub _parserScriptsIni
{
    my ($self) = @_;

    unless (defined $self->{parser}) {
        $Parse::RecDescent::skip = '';
        $self->{parser} = new Parse::RecDescent(GRAMMAR_SCRIPTS_INI) or
            throw EBox::Exceptions::Internal(__("Bad grammar"));
    }
    return $self->{parser};
}

# Method: _parserPsScriptsIni
#
#   Returns the parser for psscripts.ini file
#
sub _parserPsScriptsIni
{
    my ($self) = @_;

    unless (defined $self->{psparser}) {
        $Parse::RecDescent::skip = '';
        $self->{psparser} = new Parse::RecDescent(GRAMMAR_PSSCRIPTS_INI) or
            throw EBox::Exceptions::Internal(__("Bad grammar"));
    }
    return $self->{psparser};
}

# Method: read
#
#   Read the scripts.ini and psscripts.ini files and parse them, returning a
#   data structure with its contents:
#
#       {
#           batch => *output of GRAMMAR_SCRIPTS_INI*
#           ps => *output of GRAMMAR_PSSCRIPTS_INI*
#       }
#
sub read
{
    my ($self) = @_;

    my $data = {};

    my $scope = $self->_scope();
    my $gpo = $self->gpo();
    my $gpoFilesystemPath = $gpo->path();

    my $host = $gpo->_ldap->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal('Could not get DNS hostname');
    }

    my $smb = new EBox::Samba::SmbClient(
        target => $host, service => 'sysvol', RID => 500);

    # If the gpoFilesystemPath does not exists, it means that sysvol has not
    # been replicated yet, so return empty data
    unless ($smb->chkpath($gpoFilesystemPath)) {
        return $data;
    }

    # Create folder hierachy if not exists
    $smb->mkdir("$gpoFilesystemPath/User/Scripts") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts");
    $smb->mkdir("$gpoFilesystemPath/User/Scripts/Logon") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts/Logon");
    $smb->mkdir("$gpoFilesystemPath/User/Scripts/Logoff") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts/Logoff");

    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts");
    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts/Shutdown") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts/Shutdown");
    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts/Startup") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts/Startup");

    # Scripts indexs file paths
    my $scriptsPath = "$gpoFilesystemPath/$scope/Scripts/scripts.ini";
    my $psScriptsPath = "$gpoFilesystemPath/$scope/Scripts/psscripts.ini";

    # Check scripts.ini file exists and read it
    if ($smb->chkpath($scriptsPath)) {
        my $buffer = $smb->read_file($scriptsPath);
        $buffer = decode('UTF-16', $buffer);

        my $parser = $self->_parserScriptsIni();
        my $ret = $parser->startrule($buffer) or
            throw EBox::Exceptions::Internal(__x("Cannot parse {x} file",
                x => $scriptsPath));
        $data->{batch} = $ret;
    }

    # Ckeck psscripts.ini file exists and read it
    if ($smb->chkpath($psScriptsPath)) {
        my $buffer = $smb->read_file($psScriptsPath);
        $buffer = decode('UTF-16', $buffer);

        my $parser = $self->_parserPsScriptsIni();
        my $ret = $parser->startrule($buffer) or
            throw EBox::Exceptions::Internal(__x("Cannot parse {x} file",
                x => $psScriptsPath));
        $data->{ps} = $ret;
    }

    return $data;
}

sub write
{
    my ($self, $data) = @_;

    my $scope = $self->_scope();
    my $gpo = $self->gpo();
    my $gpoFilesystemPath = $gpo->path();

    my $host = $gpo->_ldap->rootDse->get_value('dnsHostName');
    unless (defined $host and length $host) {
        throw EBox::Exceptions::Internal('Could not get DNS hostname');
    }

    my $smb = new EBox::Samba::SmbClient(
        target => $host, service => 'sysvol', RID => 500);

    # Create folder hierachy if not exists
    $smb->mkdir("$gpoFilesystemPath/User/Scripts") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts");
    $smb->mkdir("$gpoFilesystemPath/User/Scripts/Logon") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts/Logon");
    $smb->mkdir("$gpoFilesystemPath/User/Scripts/Logoff") unless
        $smb->chkpath("$gpoFilesystemPath/User/Scripts/Logoff");

    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts");
    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts/Shutdown") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts/Shutdown");
    $smb->mkdir("$gpoFilesystemPath/Machine/Scripts/Startup") unless
        $smb->chkpath("$gpoFilesystemPath/Machine/Scripts/Startup");

    # Scripts indexs file paths
    my $scriptsPath = "$gpoFilesystemPath/$scope/Scripts/scripts.ini";
    my $psScriptsPath = "$gpoFilesystemPath/$scope/Scripts/psscripts.ini";

    # Write scripts.ini
    my $buffer = "\r\n";
    my $batchData = $data->{batch};
    foreach my $key (sort keys %{$batchData}) {
        my $aux = $batchData->{$key};
        if (keys %{$aux} > 0) {
            $buffer .= "[$key]\r\n";
            foreach my $index (sort keys %{$aux}) {
                $buffer .= "${index}CmdLine=$aux->{$index}->{CmdLine}\r\n";
                $buffer .= "${index}Parameters=$aux->{$index}->{Parameters}\r\n";
            }
            $buffer .= "\r\n";
        }
    }
    $buffer = encode('UTF-16LE', $buffer);
    $buffer = "\x{FF}" . "\x{FE}" . $buffer;
    $smb->write_file($scriptsPath, $buffer);

    # Write psscripts.ini
    $buffer = "\r\n";
    my $psData = $data->{ps};
    foreach my $key (sort keys %{$psData}) {
        my $aux = $psData->{$key};
        if (keys %{$aux} > 0) {
            $buffer .= "[$key]\r\n";
            foreach my $index (sort keys %{$aux}) {
                $buffer .= "${index}CmdLine=$aux->{$index}->{CmdLine}\r\n";
                $buffer .= "${index}Parameters=$aux->{$index}->{Parameters}\r\n";
            }
            $buffer .= "\r\n";
        }
    }
    $buffer = encode('UTF-16LE', $buffer);
    $buffer = "\x{FF}" . "\x{FE}" . $buffer;
    $smb->write_file($psScriptsPath, $buffer);

    # Update extension
    my $isUser = (lc $self->_scope() eq 'user') ? 1 : 0;
    my $cse = $self->clientSideExtensionGUID();
    my $tool = $self->toolExtensionGUID();
    $self->gpo->extensionUpdate($isUser, $cse, $tool);
}

1;
