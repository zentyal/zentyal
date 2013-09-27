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
            var html = '<li><span class="red">' + errorThrown + '</li>';
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
            $('#messages').append('<div class="error">' + errorThrown + '</div>').fadeIn();
            $('.error').delay(10 * 1000).fadeOut('slow', function() { $(this).remove(); });
        },
    });
};

/* Function to make select all works */
Zentyal.OpenChange.initTable = function (tableClass) {
    // This is more-or-less copied from z.js
    var table = $('.' + tableClass);
    if (!table) return;

    var update_select_all = function(table) {
        var checked = table.find('.table-row :checked').length;
        var unchecked = table.find('.table-row :checkbox:not(:checked)').length;
        table.find(':checkbox[name="select_all"]')
            .prop('checked', checked > 0 && unchecked == 0);
        Zentyal.OpenChange.changeUsers(checked);
    };
    table.find(':checkbox[name="select_all"]').click(function (e) {
        var checked = $(this).prop('checked');
        $(this).parents('table').find('.table-row :checkbox').prop('checked', checked);
        $(this).parents('table').find('.table-row').toggleClass('row-selected', checked);
        update_select_all($(this).parents('table'));
    });

    // Select on checkbox click
    table.find('.table-row :checkbox').click(function (e) {
        var row = $($(this).parents('.table-row')[0]);
        row.toggleClass('row-selected');
        var selected = row.hasClass('row-selected');
        var check = $(this);
        check.prop("checked", selected);
        update_select_all($(this).parents('table'));
    });

};

/* Function to change migration details based on mailboxes table */
Zentyal.OpenChange.changeUsers = function(nChecked) {
    var estBtn = $('#estimate-migration');
    if (nChecked == 0) {
        estBtn.prop('disabled', true);
        $('#migration-details').hide();
        $('#migration-no-mailboxes').fadeIn();
    } else {
        $('#migration-details').find('#mailboxes .info-value').html(nChecked);
        estBtn.prop('disabled', false);
        estBtn.fadeIn();
        $('#start-migration').hide();
        $('#migration-no-mailboxes').hide();
        $('#migration-details').fadeIn();
    }
};

/* Function to launch the estimation of the migration time */
Zentyal.OpenChange.estimateMigration = function(params) {
    $(params.estimateButton).hide();
    $(params.loadingId).show();
    // Set the form params
    var usersToMigrate = $.map($(params.tableClass).find('.table-row :checked'), function(el) { return el.value });
    $.ajax({
        type : "POST",
        url  : '/OpenChange/Migration/Estimate',
        dataType : 'json',
        data : JSON.stringify({ users : usersToMigrate }),
        contentType : 'json',
        success : function (data) {
            if ('error' in data) {
                $('#messages').append('<div class="error">' + data.error + '</div>').fadeIn();
                $('.error').delay(10 * 1000).fadeOut('slow', function() { $(this).remove(); });
                $(params.estimateButton).fadeIn();
            } else {
                var migration = $(params.migrationBlock);
                for (var property in data) {
                    migration.find('#' + property + ' .info-value').html(data[property]);
                }
                $(params.startBtnId).fadeIn();
            }
        }
    }).done(function() {
        $(params.loadingId).hide();
    });

};

// Format the bytes in readable format within the given id
// using this format: number <i>metric</i>
Zentyal.OpenChange.formatProgressBytes = function(id, bytes) {
    var container = $(id);
    if (! container) return;
    var bytStr = getBytes(bytes);
    var parts = bytStr.split(" ");
    container.html(parts[0] + ' <i>' + parts[1] + '</i>');
};