// Copyright (C) 2013-2014 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('Dialog');

Zentyal.Dialog.DEFAULT_ID = 'load_in_dialog';

Zentyal.Dialog.loadInExistent = function(dialog, url, params) {
    var data = (params.data !== undefined) ? params.data : [];
    dialog.html('<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>');
    dialog.dialog({ title: params['title'] });
    dialog.load(url, data, function(html) {
        var response;
        try {
            response=jQuery.parseJSON(html);
        } catch (error) {
            response = null;
        }
        if((response !== null) && (typeof response =='object')) {
            // for now only we are interested in a redirection, i.e we have logged out
            //  and we must redirect to login
            if ('redirect' in response) {
                window.location = response.redirect;
            }
        }
        if (typeof(params.load) === 'function')  {
            params.load.apply(this);
        }
    });
};

// TODO: Doc
Zentyal.Dialog.showURL = function(url, params) {
    var i,
        dialogParams,
    dialogParamsAllowed = ['title', 'width', 'height', 'dialogClass', 'buttons'];
    if (params === undefined) {
        params = {};
    }

    var existentDialog = $('#' + Zentyal.Dialog.DEFAULT_ID);
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
            Zentyal.Dialog.loadInExistent($(event.target), url, params);
        },
        close:  function (event, ui) {
            if (typeof(params.close) === 'function') {
                params.close(event, ui);
            }
            $(event.target).dialog('destroy');
        }
    };
    for (i=0; i < dialogParamsAllowed.length; i++) {
        var paramName = dialogParamsAllowed[i];
        if (paramName in params) {
            dialogParams[paramName] = params[paramName];
        }
    }
    if (('showCloseButton' in params) & (!params.showCloseButton)) {
        dialogParams['dialogClass'] = 'no-close';
        dialogParams['closeOnEscape'] = false;
    }

    $('<div id="' + Zentyal.Dialog.DEFAULT_ID + '"></div>').dialog(dialogParams);
};

Zentyal.Dialog.showHTML = function(html, params) {
    $('#' + Zentyal.Dialog.DEFAULT_ID).html(html).dialog(params);
};

Zentyal.Dialog.close = function() {
    $('#' + Zentyal.Dialog.DEFAULT_ID).dialog('close');
};

Zentyal.Dialog.submitForm = function(formSelector, params) {
    var form = $(formSelector);
    var url  = form.attr('action');
    var data = form.serialize();
    var errorSelector = '#' + form.attr('id') + '_error';
    if (params == undefined) {
        params = {};
    }
    if (params.extraData !== undefined) {
        $.each(params.extraData, function(name, value) {
            data += '&' + name + '=' + value;
        });
    }

    $(errorSelector).html('').hide();
    $.ajax({
        url : url,
        data: data,
        dataType: 'json',
        type: 'post',
        success: function (response){
            if (response.success) {
                if ('success' in params) {
                    params.success(response);
                }
            } else {
                $(errorSelector).html(response.error).show();
                if ('error' in params) {
                    params.error(response);
                }
            }
            if ('complete' in params) {
                params.complete(response);
            }
            if ('redirect' in response) {
                window.location.replace(response.redirect);
            }
        },
        error: function(jqXHR){
            $(errorSelector).html(jqXHR.responseText).show();
        }
    });
};
