// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

window.helpShown = false;

function showHelp() {
    helpShown = true;
    _applyHelpStyles('inline', 'none', 'block');
}

function hideHelp() {
    helpShown = false;
    _applyHelpStyles('none', 'inline', 'none');
}

function _applyHelpStyles(hideHelpDisplay, showHelpDisplay, helpElementsDisplay) {
    jQuery('#hidehelp').css('display', hideHelpDisplay);
    jQuery('#showhelp').css('display', showHelpDisplay);
    jQuery('.help').each(function(i, e) {
        jQuery(this).css('display', helpElementsDisplay);
    });
}

function initHelp() {
    if(jQuery('.help').length == 0) {
        jQuery('#helpbutton').hide(0);
    } else {
        jQuery('#helpbutton').show(0);
        if (helpShown) {
            showHelp();
        } else {
            hideHelp();
        }
    }
}

initHelp();
jQuery('body').bind('DOMNodeInserted', initHelp, false);

