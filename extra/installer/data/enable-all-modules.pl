#!/usr/bin/perl
use EBox;
use EBox::Global;
use EBox::ServiceModule::Manager;

EBox::init();

my $global = EBox::Global->getInstance();

my $mgr = EBox::ServiceModule::Manager->new();
$mgr->enableAllModules();

$global->revokeAllModules();

if ($global->modExists('network')) {
	my $network = $global->modInstance('network');
	$network->enableService('1');
	$network->saveConfig();
}


# Stop mail sytem
if ($global->modExists('mail')) {
	my $mail = $global->modInstance('mail');
	$mail->enableService(undef);
	$mail->save();
}

if ($global->modExists('mailfilter')) {
	my $mail = $global->modInstance('mailfilter');
	$mail->enableService(undef);
	$mail->save();
}


$mgr->updateDigests();

