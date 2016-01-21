# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Printers::Model::Printers;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::View::Customizer;
use EBox::Types::Text;
use EBox::Types::HasMany;
use Net::CUPS;
use EBox::Validate;

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'printer',
            printableName => __('Printer name'),
            unique => 0,
            editable => 0
        ),
        new EBox::Types::Text(
            fieldName => 'description',
            printableName => __('Description'),
            editable => 0,
            optional => 1,
        ),
        new EBox::Types::Text(
            fieldName => 'location',
            printableName => __('Location'),
            editable => 0,
            optional => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'guest',
            printableName => __('Guest access'),
            editable      => 1,
            defaultValue  => 0,
            help          => __('This printer will not require authentication.'),
        ),
        new EBox::Types::HasMany(
            fieldName     => 'access',
            printableName => __('Access control'),
            foreignModel => 'PrinterPermissions',
            view => '/Printers/View/PrinterPermissions'
        ),
    );

    my $dataForm =
    {
        tableName          => 'Printers',
        printableTableName => __('Printer permissions'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        modelDomain        => 'Printers',
        sortedBy           => 'printer',
        printableRowName   => __('printer'),
        withoutActions     => 1,
        help               => __('Here you can define the access control list for your printers.'),
    };
    return $dataForm;
}

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the VPN is not enabled or configured
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();
    $customizer->setModel($self);
    $customizer->setPermanentMessage($self->_configureMessage());

    return $customizer;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    # If CUPS is not running an empty list will be returned and all printers
    # will be removed, so only sync rows if CUPS daemon is running.
    return 0 unless $self->parentModule->isRunning();

    my $cupsPrinters = $self->cupsPrinters();
    my %cupsPrinters = map {
        my $printer = $_;
        my $name = $printer->getName();
        utf8::decode($name);
        ($name => $printer)
    } @{$cupsPrinters};
    my %currentPrinters = map {
        my $id = $_;
        $self->row($id)->valueByName('printer') => $id
    } @{$currentIds};

    my $modified = 0;

    foreach my $printerName (keys %cupsPrinters) {
        my $p = $cupsPrinters{$printerName};
        my $desc = $p->getDescription();
        defined $desc or $desc = '';
        utf8::decode($desc);
        my $loc = $p->getLocation();
        defined $loc or $loc = '';
        utf8::decode($loc);

        my $existentId = exists $currentPrinters{$printerName} ?
            $currentPrinters{$printerName} : undef;
        if ($existentId) {
            my $row = $self->row($existentId);
            if (($row->valueByName('description') ne $desc) or
                 ($row->valueByName('location') ne $loc)
                ) {
                $row->elementByName('description')->setValue($desc);
                $row->elementByName('location')->setValue($loc);
                $row->store();
                $modified = 1;
            }
        } else {
            $self->add(printer => $printerName, description => $desc,
                       location => $loc, guest => 0);
            $modified = 1;
        }

    }

    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $printerName = $row->valueByName('printer');
        next if exists $cupsPrinters{$printerName};
        $self->removeRow($id);
        $modified = 1;
    }

    EBox::Global->modChange('samba') if ($modified);

    return $modified;
}

sub cupsPrinters
{
    my ($self) = @_;

    my $cups = Net::CUPS->new();
    my @printers = $cups->getDestinations();
    return \@printers;
}

# Method: precondition
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->parentModule()->isEnabled();
}

# Method: preconditionFailMsg
#
# Overrides:
#
#      <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __x('Prior to configure printers ACLs you need to enable '
               . 'the module in the {openref}Module Status{closeref} '
               . ' section and save changes after that.',
               openref => '<a href="/ServiceModule/StatusView">',
               closeref => '</a>');
}

sub _configureMessage
{
    my ($self) = @_;
    my $global = $self->global(1); # RO bz we want to check enforced interfaces

    my $HOST    = 'localhost';
    my $CUPS_PORT = 631;
    my $request = $global->request();
    my $clientAddress =  $request->address();
    if ($clientAddress) {
        my $cidrAddr = $clientAddress . '/32';
        my $networkMod = $global->modInstance('network');
        foreach my $iface (@{$networkMod->allIfaces()}) {
            my $host = $networkMod->ifaceAddress($iface);
            my $mask = $networkMod->ifaceNetmask($iface);
            (defined($host) and defined($mask)) or next;

            EBox::Validate::checkIPNetmask($clientAddress, $mask) or next;
            if (EBox::Validate::isIPInNetwork($host,$mask,$cidrAddr)) {
                $HOST = $host;
                last;
            }
        }
    }
    my $URL = "https://$HOST:$CUPS_PORT/admin";

    my $message = __x('To add or manage printers you have to use the {open_href}CUPS Web Interface{close_href}',
                      open_href => "<a href='$URL' target='_blank' id='cups_url'>",
                      close_href => '</a>');
    if ($HOST eq 'localhost') {
        $message .= "<script>document.getElementById('cups_url').href='https://' + document.domain + ':$CUPS_PORT/admin';</script>";
    }

    return $message;
}

1;
