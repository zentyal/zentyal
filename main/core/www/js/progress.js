// Copyright (C) 2004-2012 eBox Technologies S.L. licensed under the GPLv2

// code used by progress.mas
var percent = 0;
var time = 0;

var ticks = 0;
var totalTicks = 0;

// Update the page
function updatePage (xmlHttp, nextStepTimeout, nextStepUrl) {
    var rawResponse = xmlHttp.responseText.replace(/\n/g, "<br />");
    var response = eval("(" + rawResponse + ")");

    if (xmlHttp.readyState == 4) {
        if (response.state == 'running') {
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
                percent = Math.ceil((ticks/totalTicks)*100);
                ph.setValue(percent);
            }
        }
        else if (response.state == 'done') {
            pe.stop();
            if ( nextStepTimeout > 0 ) {
//                setTimeout ( "location.href='" + nextStepUrl + "';", nextStepTimeout*1000 );
              loadWhenAvailable(nextStepUrl, nextStepTimeout);
            }

            if ( 'errorMsg' in response.statevars ) {
                $('warning-progress-messages').update(
                    response.statevars.errorMsg);

                $('done').removeClassName('note');
                $('done').addClassName('warning');
                $('warning-progress').show();
                $('warning-progress-messages').show();
            }

            Element.hide('progressing');
            Element.show('done');

            // Used to tell selenium we are done
            // with saving changes
            $('ajax_request_cookie').value = 1337;
        }
        else if (response.state == 'error') {
            Element.hide('progressing');
            Element.show('error-progress');
            pe.stop();
            if ( 'errorMsg' in response.statevars ) {
                $('error-progress-message').update(
                    response.statevars.errorMsg);
            }
        }
    }
}

// Generate an Ajax request to fetch the current package
function callServer(progressId, url, nextStepTimeout, nextStepUrl) {

    // Build the URL to connect to
    var par = "progress=" + progressId ;

    new Ajax.Request(url, {
        method: 'post',
        parameters: par,
        asynchronous: true,
        onSuccess: function (t) { updatePage(t, nextStepTimeout, nextStepUrl) }
        }
    );
    time++;
    if (time >= 30) {
        time = 0;
        showAds();
    }


}


var pe;
function createPeriodicalExecuter(progressId, currentItemUrl,  reloadInterval, nextStepTimeout, nextStepUrl)
{
    var callServerCurriedBody = "callServer(" + progressId + ", '"
                                                + currentItemUrl  + "', "
                                                + nextStepTimeout + ", '"
                                                + nextStepUrl + "')";

    callServerCurried = new Function(callServerCurriedBody );

    pe = new PeriodicalExecuter(callServerCurried, reloadInterval);
}


var progress_pl; // use progress_pe if it works
function loadWhenAvailable(url, secondsTimeout)
{
  var loadMethod = function() {
       new Ajax.Request(url, {
                             onSuccess: function(transport) {

                               if (transport.responseText) {
                                  progress_pl.stop();
                                  window.location.replace(url);                               }

                              }
                            }
                        );
  };
  progress_pl = new PeriodicalExecuter(loadMethod, secondsTimeout);
}

