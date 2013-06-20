"use strict";
jQuery.noConflict();

Zentyal.namespace('Dialog');

Zentyal.Dialog.DEFAULT_ID = 'load_in_dialog';

Zentyal.Dialog.loadInExistent = function(dialog, url, params) {
    var data = (params.data !== undefined) ? params.data : [];
    dialog.html('<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>');
    dialog.load(url, data, function(html) {
                    if (typeof(params.load) === 'function')  {
                        params.load.apply(this);
                    }
                });
};

Zentyal.Dialog.showURL = function(url, params) {
    var i,
        dialogParams,
    dialogParamsAllowed = ['title', 'width', 'height', 'dialogClass'];
    if (params === undefined) {
        params = {};
    }

    var existentDialog = jQuery('#' + Zentyal.Dialog.DEFAULT_ID);
    if (existentDialog.length > 0) {
        Zentyal.Dialog.loadInExistent(existentDialog, url, params);
        return;
    }
    dialogParams = {
        resizable: false,
        modal: true,
        minWidth: 500,
        position: {my: 'top+100', at: 'top'},
        create: function (event, ui) {
            Zentyal.Dialog.loadInExistent(jQuery(event.target), url, params);
        },
        close:  function (event, ui) {
            if (typeof(params.close) === 'function') {
                params.close(event, ui);
            }
            jQuery(event.target).dialog('destroy');
        }
    };
    for (i=0; i < dialogParamsAllowed.length; i++) {
        var paramName = dialogParamsAllowed[i];
        if (paramName in params) {
            dialogParams[paramName] = params[paramName];
        }
    }



    jQuery('<div id="' + Zentyal.Dialog.DEFAULT_ID + '"></div>').dialog(dialogParams);
};

Zentyal.Dialog.close = function() {
    jQuery('#' + Zentyal.Dialog.DEFAULT_ID).dialog('close');
};

Zentyal.Dialog.submitForm = function(formSelector, extraData) {
    var form = jQuery(formSelector);
    var url  = form.attr('action');
    var data = form.serialize();
    jQuery.each(extraData, function(name, value) {
        data += '&' + name + '=' + value;
    });

    jQuery.ajax({
        url : url,
        data: data,
        dataType: 'json',
        success: function (response){
            if (response.success) {
                if ('redirect' in response) {
                    window.location = response.redirect;
                } else {
                    Zentyal.Dialog.close();
                }
            } else {
                jQuery('#error_' + form.attr('id')).html(response.error).show();
            }
        },
        error: function(jqXHR){
            jQuery('#error').html(jqXHR.responseText).show();
        }
    });
};