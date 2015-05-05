"use strict";

Zentyal.namespace('Form');

Zentyal.Form._savedHtml = {};
Zentyal.Form.setLoading = function(selector) {
    var collection = $(selector);
    collection.each(function(index, el) {
        var jqEl = $(el);
        Zentyal.Form._savedHtml[jqEl.attr('id')] = jqEl.html();
        jqEl.html('<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>');
    });
    return collection;
};

Zentyal.Form.restoreAfterLoading = function(selector) {
    var collection = $(selector);
    collection.each(function(index, el) {
        var jqEl = $(el);
        var id = jqEl.attr('id');
        if (id in Zentyal.Form._savedHtml) {
            var html = Zentyal.Form._savedHtml[id];
            jqEl.html(html);
            delete  Zentyal.Form._savedHtml[id];
        } else {
            console.error(id + ' not found in saved html');
        }
    });
    return collection;
};


Zentyal.Form.setupAjaxSubmit = function(formSelector, params) {
    var form = $(formSelector);
    form.on('submit', function(event) {
        event.preventDefault();
        Zentyal.Form.submit(form, params);
   });
};


Zentyal.Form.submit = function (formSelector, params) {
    var form = $(formSelector);
    var submitButton = $(params.submitButton);
    Zentyal.Form.setLoading(submitButton);
    var noteDiv =  $(params.noteDiv);
    noteDiv.hide();
    var errorDiv = $(params.errorDiv);
    errorDiv.hide();

    var url = form.attr('action');
    var data;
    if ('data' in params) {
        data = params.data;
    } else {
        data = form.serialize();
    }

    $.ajax({
        url : url,
        data: data,
        dataType: 'json',
        type: 'post',
        success: function (response){
            if (response.success) {
                if ('msg' in response) {
                    noteDiv.html(response.msg).show();
                }
            } else if ('error' in response) {
                errorDiv.html(response.error).show();
            }

            if ('success' in params) {
                params.success(response);
            }
        },
        error: function(jqXHR){
            errorDiv.html(jqXHR.responseText).show();
        },
        complete: function() {
            Zentyal.Form.restoreAfterLoading(submitButton);
        }
    });
};

