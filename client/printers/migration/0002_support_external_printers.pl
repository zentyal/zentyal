#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Printers;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    my @conf;
    
    my $printers = EBox::Global->modInstance('printers'); 
    my @idprinters = $printers->all_dirs("printers");
    for my $dirid (@idprinters){
        my $id = $dirid;
        $id =~  s'.*/'';
        unless ($printers->_printerConfigured($id)){
            $printers->removePrinter($id);
            next;
        }
        $printers->_setDriverOptionsToFile($id);
        my $printer = $printers->_printerInfo($id);
        $printer->{location} = $printers->_location($id);
        push (@conf, $printer );
    }

    $printers->writeConfFile(EBox::Printers::CUPSPRINTERS, 
            'printers/printers.conf.mas', 
            ['printers' => \@conf]);

}


EBox::init();

my $printersMod = EBox::Global->modInstance('printers');
my $migration =  __PACKAGE__->new( 
    'gconfmodule' => $printersMod,
    'version' => 2 
);
$migration->execute();
