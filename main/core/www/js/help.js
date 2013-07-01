// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('Help');

Zentyal.Help.helpShown = false;

Zentyal.Help.showHelp = function () {
    Zentyal.Help.helpShown = true;
    $('#hidehelp, .help').show();
    $('#showhelp').hide();
};

Zentyal.Help.hideHelp = function () {
    Zentyal.Help.helpShown = false;
    $('#hidehelp, .help').hide();
    $('#showhelp').show();
};

Zentyal.Help.initHelp = function () {
    if($('.help').length === 0) {
        $('#helpbutton').hide();
    } else {
        $('#helpbutton').show();
        if (Zentyal.Help.helpShown) {
            Zentyal.Help.showHelp();
        } else {
            Zentyal.Help.hideHelp();
        }
    }
};

Zentyal.Help.initHelp();
$('body').bind('DOMNodeInserted', Zentyal.Help.initHelp, false);

