// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('OpenChange');

Zentyal.OpenChange.updateAjaxValue = function(url, containerId) {
    var escapedId = Zentyal.escapeSelector(containerId);
    $.ajax({
         url: url,
         datatype: 'json',
         timeout: 3000,
         success: function (data, textStatus) {
            var container = $('#' + escapedId);
            //container.removeClass().addClass('summary_value summary_' + response.type);
            container.html(data.value);
            $( ".select-server-button" ).click( function() {
                var $this = $(this);
                var name = $this.data('server');
                $("#server").val(name);
            });
         },
         error: function ( jqXHR, textStatus, errorThrown ) {
            var container = $('#' + escapedId);
            var html = '<li><span class="red">' + textStatus + '</li>';
            container.html(html);
         },
    });
};
