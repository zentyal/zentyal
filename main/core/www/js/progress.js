// Copyright (C) 2007 Warp Networks S.L
// Copyright (C) 2008-2012 Zentyal S.L. licensed under the GPLv2

// code used by progress.mas
var percent = 0;
var time = 0;

var ticks = 0;
var totalTicks = 0;


function porcentH(i){
  this.value = 0;
  this.setValue = function(v){
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

};

var ph = new porcentH('progress');

// Update the page
function updatePage (xmlHttp, nextStepTimeout, nextStepUrl, showNotesOnFinish) {
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
            pe.stop();
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

// Generate an Ajax request to fetch the current package
function callServer(progressId, url, nextStepTimeout, nextStepUrl, showNotesOnFinish) {

    // Build the URL to connect to
    var par = "progress=" + progressId ;

    new Ajax.Request(url, {
        method: 'post',
        parameters: par,
        asynchronous: true,
                       onSuccess: function (t) { updatePage(t, nextStepTimeout, nextStepUrl, showNotesOnFinish); }
        }
    );
    time++;
    if (time >= 10) {
        time = 0;
      if (window.showAds) {
        showAds(1);
      }
    }


}


var pe;
function createPeriodicalExecuter(progressId, currentItemUrl,  reloadInterval, nextStepTimeout, nextStepUrl, showNotesOnFinish)
{
    var callServerCurriedBody = "callServer(" + progressId + ", '"
                                                + currentItemUrl  + "', "
                                                + nextStepTimeout + ", '"
                                                + nextStepUrl + "', " +
                                                + showNotesOnFinish +  ")";

    var callServerCurried = new Function(callServerCurriedBody );

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

