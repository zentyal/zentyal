// Copyright (C) 2004-2007 Warp Networks S.L.
// Copyright (C) 2008-2013 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('Help');

Zentyal.Help.helpShown = false;

Zentyal.Help.showHelp = function () {
    Zentyal.Help.helpShown = true;
    $('.help').slideToggle('fast');
};

Zentyal.Help.initHelp = function () {
    var hasHelp = $('.help').length > 0;
    $('#helpbutton').toggle(hasHelp);
};

$(function(){
    Zentyal.Help.initHelp();
});
$('body').bind('DOMNodeInserted', Zentyal.Help.initHelp, false);

