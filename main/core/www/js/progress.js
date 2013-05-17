// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2

// code used by progress.mas

"use strict";
jQuery.noConflict();
Zentyal.namespace('ProgressIndicator');

Zentyal.ProgressIndicator.updateProgressBar = function(ticks, totalTicks) {
    var percent;
    if (totalTicks > 0) {
        percent = Math.ceil((ticks/totalTicks)*100);
        if( percent > 100)
            percent = 100;
        if(percent < 0)
            percent = 0;
    } else {
        percent = 0;
    }
    $('progressValue').morph('width: ' + percent + '%', { duration: 0.5 });
// XX solve animation problems
//    jQuery('#progressValue').animate( { width: percent + '%' }, { duration: 500} );
    jQuery('#percentValue').html(percent+"%");
};

Zentyal.ProgressIndicator.updatePage  = function(xmlHttp,  timerId, nextStepTimeout, nextStepUrl, showNotesOnFinish) {
    var response = jQuery.parseJSON(xmlHttp.responseText);

    if (xmlHttp.readyState == 4) {
        if (response.state == 'running') {
            var ticks = 0;
            var totalTicks = 0;
            if (('message' in response) && response.message.length > 0 ) {
                jQuery('#currentItem').html(response.message);
            }
            if ( ('ticks' in response) && (response.ticks >= 0)) {
                jQuery('#ticks').html(response.ticks);
                ticks = response.ticks;
            }
            if ( ('totalTicks' in response) && (response.totalTicks > 0)) {
                jQuery('#totalTicks').html(response.totalTicks);
                totalTicks = response.totalTicks;
            }

            if ( totalTicks > 0 ) {
                Zentyal.ProgressIndicator.updateProgressBar(ticks, totalTicks);
            }
        } else if (response.state == 'done') {
            clearInterval(timerId);
            if ( nextStepTimeout > 0 ) {
              Zentyal.ProgressIndicator.loadWhenAvailable(nextStepUrl, nextStepTimeout);
            }

          if (showNotesOnFinish) {
            if (('errorMsg' in response) && (response.errorMsg)) {
                jQuery('#warning-progress-messages').html(response.errorMsg);

                jQuery('#done_note').removeClass('note').addClass('warning');
                jQuery('#warning-progress').show();
                jQuery('#warning-progress-messages').show();
            }

              jQuery('#progressing').hide();
              jQuery('#done').show();
          }

            // Used to tell selenium we are done
            // with saving changes
            jQuery('ajax_request_cookie').val(1337);
        } else if (response.state == 'error') {
            clearInterval(timerId);
            if (showNotesOnFinish) {
                jQuery('#progressing').hide();
            }

            jQuery('#error-progress').show();
            // check if we are in a modal box..
            if (jQuery('div#MB_frame').length > 0) {
                Modalbox.resizeToInclude(this);
                Modalbox.resize(0, +20);
            }

            if ('errorMsg' in response) {
                jQuery('#error-progress-message').html(response.errorMsg);
            }
        }
    }
};

Zentyal.ProgressIndicator.updateProgressIndicator = function(progressId, currentItemUrl,  reloadInterval, nextStepTimeout, nextStepUrl, showNotesOnFinish) {
    var time = 0;
    var requestParams = "progress=" + progressId ;
    var callServer = function() {
        jQuery.ajax({
            url: currentItemUrl,
            data: requestParams,
            type : 'POST',
            complete: function (xhr) {
                Zentyal.ProgressIndicator.updatePage(xhr, timerId, nextStepTimeout, nextStepUrl, showNotesOnFinish);
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
};

Zentyal.ProgressIndicator.loadWhenAvailable = function(url, secondsTimeout) {
    var loadMethod = function() {
        jQuery.ajax({
            url: url,
            success: function (text) {
                        if (text) {
                            clearInterval(timerId);
                            window.location.replace(url);                               }
            }
        });
    };

    var timerId = setInterval(loadMethod, secondsTimeout*1000);
};

Zentyal.ProgressIndicator.adsSlides = function(nSlides) {
    jQuery('#adsButtonPrev').hide();

    var car_options = {
          'auto' : true,
          'frequency' : 20,
          'circular' : true,
          'duration' : 0.8,
          'wheel' : false,
          'afterMove': null
    };

    // XXX MIGRATE carousel.js
    var car_obj = new Carousel('slide_wrapper', $$('#slides .ads'), $$('a.carousel-control'), car_options);

    car_obj.options.afterMove = function () {
          var slide_num = car_obj.current._index;
          if (slide_num === 0) {
              jQuery('#adsButtonPrev').hide();
          } else if (slide_num >= nSlides) {
              jQuery('#adsButtonNext').hide();
          } else {
              jQuery('#adsButtonPrev').show();
              jQuery('#adsButtonNext').show();
          }
      };
};

