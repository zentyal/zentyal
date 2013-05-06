// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

Zentyal.namespace('Dashboard');

Zentyal.Dashboard.updateAjaxValue = function(url, containerId) {
    jQuery.ajax({
         url: url,
         datatype: 'json',
         success: function (response) {
            var container = jQuery('#' + container_id);
            container.removeClass().addClass('summary_value', 'summary_' + response.responseJSON.type);
            container.html(response.responseJSON.value);
         }
    });
};
