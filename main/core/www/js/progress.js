// Copyright (C) 2004-2012 eBox Technologies S.L. licensed under the GPLv2
// code used by progress.mas

"use strict";
jQuery.noConflict();

function percentH(i){
    this.value = 0;
    this.ticks = 0;
    this.totalTicks = 0;
    this.setValue = function(ticks, totalTicks){
        this.ticks = ticks;
        this.totalTicks = totalTicks;
        var v = Math.ceil((ticks/totalTicks)*100);
        if(v > 100)
            v = 100;
        if(v < 0)
            v = 0;
        this.value = v;
        $('progressValue').morph('width: ' + v + '%', { duration: 0.5 });
        document.getElementById('percentValue').innerHTML= v+"%";
  };

  this.upValue = function(v){
    v += this.value;
    this.setValue(v);
  };

  this.downValue = function(v){
    v = this.value - v;
    this.setValue(v);
  };

}

// Update the page
function updatePage (xmlHttp, ph, timerId, nextStepTimeout, nextStepUrl, showNotesOnFinish) {
    var response = jQuery.parseJSON(xmlHttp.responseText);

    if (xmlHttp.readyState == 4) {
        if (response.state == 'running') {
            var ticks = 0;
            var totalTicks = 0;
            // current item
            if (('message' in response) && response.message.length > 0 ) {
                $('currentItem').innerHTML = response.message;
            }
            if ( ('ticks' in response) && (response.ticks >= 0)) {
                $('ticks').innerHTML = response.ticks;
                ticks = response.ticks;
            }
            if ( ('totalTicks' in response) && (response.totalTicks > 0)) {
                $('totalTicks').innerHTML = response.totalTicks;
                totalTicks = response.totalTicks;
            }

            if ( totalTicks > 0 ) {
                ph.setValue(ticks, totalTicks);
            }
        }
        else if (response.state == 'done') {
            clearInterval(timerId);
            if ( nextStepTimeout > 0 ) {
              loadWhenAvailable(nextStepUrl, nextStepTimeout);
            }

          if (showNotesOnFinish) {
            if (('errorMsg' in response) && (response.errorMsg)) {
                $('warning-progress-messages').update(
                    response.errorMsg);

                $('done_note').removeClassName('note');
                $('done_note').addClassName('warning');
                $('warning-progress').show();
                $('warning-progress-messages').show();
            }

            Element.hide('progressing');
            $('done').show();
          }

            // Used to tell selenium we are done
            // with saving changes
            $('ajax_request_cookie').value = 1337;
        }
        else if (response.state == 'error') {
            clearInterval(timerId);
            if (showNotesOnFinish) {
               Element.hide('progressing');
            }

            $('error-progress').show();
            if ('errorMsg' in response) {
                $('error-progress-message').update(
                    response.errorMsg);
            }
        }
    }
}

function updateProgressIndicator(progressId, currentItemUrl,  reloadInterval, nextStepTimeout, nextStepUrl, showNotesOnFinish)
{
    var time = 0;
    var requestParams = "progress=" + progressId ;
    var ph = new percentH('progress');
    var callServer = function() {
        jQuery.ajax({
            url: currentItemUrl,
            data: requestParams,
            type : 'POST',
            complete: function (xhr) {
                // TODO check ofr success
                updatePage(xhr, ph, timerId, nextStepTimeout, nextStepUrl, showNotesOnFinish);
            }
        });
        time++;
        if (time >= 10) {
            time = 0;
            if (window.showAds) {
                showAds(1);
            }
        }
    };

    var timerId = setInterval(callServer, reloadInterval*1000);
}

function loadWhenAvailable(url, secondsTimeout)
{
    var loadMethod = function() {
        jQuery.ajax({
            url: url,
            success: function (xhr) {
                        if (transport.responseText) {
                            clearInterval(timerId);
                            window.location.replace(url);                               }
            }
        });
    };

    var timerId = setInterval(loadMethod, secondsTimeout*1000);
}

