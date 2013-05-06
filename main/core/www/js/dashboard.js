// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

Zentyal.namespace('Dashboard');

Zentyal.Dashboard.updateAjaxValue = function(url, containerId) {
    var escapedId = Zentyal.escapeJQSelector(containerId);
    jQuery.ajax({
         url: url,
         datatype: 'json',
         success: function (response) {
            var container = jQuery('#' + escapedId);
            container.removeClass().addClass('summary_value', 'summary_' + response.responseJSON.type);
            container.html(response.responseJSON.value);
         }
    });
};

// XXX migrate blind effect
Zentyal.Dashboard.toggleClicked = function(element) {
    var elementId = Zentyal.escapeJQSelector(element);
    var contentSelector = '#' + elementId + '_content';
    var toggler = jQuery('#' + elementId + '_toggler');
    if(toggler.hasClass('minBox')) {
//        Effect.BlindUp(contentname, { duration: 0.5 });
        jQuery(contentSelector).hide();//('blind', { direction: 'vertical' }, 500);
        toggler.removeClass('minBox').addClass('maxBox');
    } else {
//        Effect.BlindDown(contentname, { duration: 0.5 });
        jQuery(contentSelector).show(); //('blind', { direction: 'vertical' }, 500);
        toggler.removeClass('maxBox').addClass('minBox');
    }
    jQuery.ajax({
         url: "/Dashboard/Toggle",
         type: 'post',
         data:  { element: element }
    });
};

