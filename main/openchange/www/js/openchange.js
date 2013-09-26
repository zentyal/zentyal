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

Zentyal.OpenChange.setMailboxes = function (url, containerId) {
    var escapedContainerId = Zentyal.escapeSelector(containerId);
    $.ajax( {
        method: "GET",
        url: url,
        datatype : 'html',
        success: function(data) {
            $('#' + escapedContainerId).html(data)
            Zentyal.OpenChange.initTable('migration-table');
        },
        error: function(jqXHR, textStatus, errorThrown) {
            alert(textStatus);
        },
    });
};

Zentyal.OpenChange.initTable = function (tableClass) {
    // This is copied from z.js
    var table = $('.' + tableClass)
    if (!table) return;

    var update_select_all = function(table) {
        var checked = table.find('.table-row :checked').length;
        var unchecked = table.find('.table-row :checkbox:not(:checked)').length;
        table.find(':checkbox[name="select_all"]')
            .prop('checked', checked > 0 && unchecked == 0);
    };
    table.find(':checkbox[name="select_all"]').click(function (e) {
        var checked = $(this).prop('checked');
        $(this).parents('table').find('.table-row :checkbox').prop('checked', checked);
//        $(this).parents('table').find('.table-row').toggleClass('selected', checked);
        update_select_all($(this).parents('table'));
    });

    // Select on checkbox click
    table.find('.table-row :checkbox').click(function (e) {
        //var row = $($(this).parents('.table-row')[0]);
        // row.toggleClass('selected');
        // var selected = row.hasClass('selected')
        //var check = $(this)
        //check.prop("checked", selected);
        update_select_all($(this).parents('table'));
    });

};