// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

Zentyal.namespace('Help');

Zentyal.Help.helpShown = false;

Zentyal.Help.showHelp = function () {
    Zentyal.Help.helpShown = true;
    jQuery('#hidehelp, .help').show();
    jQuery('#showhelp').hide();
};

Zentyal.Help.hideHelp = function () {
    Zentyal.Help.helpShown = false;
    jQuery('#hidehelp, .help').hide();
    jQuery('#showhelp').show();
};

Zentyal.Help.initHelp = function () {
    if(jQuery('.help').length === 0) {
        jQuery('#helpbutton').hide();
    } else {
        jQuery('#helpbutton').show();
        if (Zentyal.Help.helpShown) {
            Zentyal.Help.showHelp();
        } else {
            Zentyal.Help.hideHelp();
        }
    }
};

Zentyal.Help.initHelp();
jQuery('body').bind('DOMNodeInserted', Zentyal.Help.initHelp, false);

