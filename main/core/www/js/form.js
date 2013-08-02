"use strict";

Zentyal.namespace('Form');

Zentyal.Form._loadingHtml = '<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>';

Zentyal.Form.setupAjaxSubmit = function(formSelector, params) {
    var form = $(formSelector);
    var submitHtml;
    form.on('submit', function(event) {
        event.preventDefault();
        var submitButton = $(params.submitButton);
        submitHtml = submitButton.html();
        submitButton.html(Zentyal.Form._loadingHtml);
        var noteDiv =  $(params.noteDiv);
        noteDiv.hide();
        var errorDiv = $(params.errorDiv);
        errorDiv.hide();

        var url = form.attr('action');
        var data = form.serialize();
        $.ajax({
            url : url,
            data: data,
            dataType: 'json',
            success: function (response){
              if (response.success) {
                  if ('msg' in response) {
                     noteDiv.html(response.msg).show();
                  }
              } else if ('error' in response) {
                 errorDiv.html(response.error).show();
              }
           },
           error: function(jqXHR){
              errorDiv.html(jqXHR.responseText).show();
           },
           complete: function() {
               submitButton.html(submitHtml);
           }
    });
   });
};


