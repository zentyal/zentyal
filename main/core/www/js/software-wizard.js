"use strict";
jQuery.noConflict();

var DURATION = 500;
var actualPage = 0;
var visible = 0;
var firstLoad = true;
var firstInstall = false;
var isLoading = false;
var pages = null;
var gettext = null;

function setPages(newPages)
{
  pages = newPages;
}

function setFirstInstall(first)
{
  firstInstall = first;
}

function setGettext(gett)
{
  gettext = gett;
}

// enable/disable next step buttons
function setLoading(loading) {
    if (loading) {
        // Disable more clicks
        jQuery('#wizard-loading1').show(0);
        jQuery('button').attr('disabled','disabled').hide(0);
        isLoading = true;
    } else {
        jQuery('#wizard-loading1').hide(0);
        jQuery('button').removeAttr('disabled').show(0);
        isLoading = false;
    }
}
window.setLoading = setLoading;

// Load a wizard page
function loadPage(index) {
    if ( index < 0 || index > pages.length ) return;

    setLoading(true);

    jQuery('#wizard_error').hide(0).html('');

    var hiddenNumber = visible;
    var showedNumber = (visible + 1) % 2;
    if ( firstLoad ) {
        showedNumber = visible;
        firstLoad = false;
    }
    visible = showedNumber;

    if ( index > 0 ) {
        jQuery("#wizardPage" + hiddenNumber).slideUp(DURATION);
    }

    // Final stage?
    if ( index >= pages.length ) {
        jQuery('#wizard-next1').hide(0);
        jQuery('#wizard-next2').hide(0);
        setLoading(false);
        finalPage(firstInstall);
        return;
    }

    var loaded = function(code) {
        var showed = jQuery("#wizardPage" + showedNumber);
        showed.show(0).html(code).slideDown(DURATION);
        var form = jQuery('#wizardPage' + showedNumber + ' form')[0];
        // avoid automatic form submition (by enter press)
        if ( form ) {
            jQuery(form).submit(function() { return false; });
        }

        setLoading(false);
        if ( index == pages.length-1 ) {
            var finishString = gettext('Finish');
            jQuery('#wizard-next1')[0].value = finishString;
            jQuery('#wizard-next2')[0].value = finishString;
        }
    };

    jQuery.ajax({
        url: pages[index],
        dataType: 'text',
        success: loaded
    });
    actualPage = index;
}

// Skip this page
function skipStep() {
    loadPage(actualPage+1);
}

// Save changes and step into next page
function nextStep() {
    // avoid possible mess by page calls to this function
    if (isLoading) return;
    setLoading(true);
    // Submit form
    var form = jQuery('#wizardPage' + visible + ' form');
    var onFail = function(response) {
        jQuery('#wizard_error').show(0).html(response.responseText).fadeIn();
        setLoading(false);
    };
    var onSuccess = function(response) {
            loadPage(actualPage+1);
    };

    jQuery.ajax({
        url: form.attr('action'),
        type: 'POST',
        data: form.serialize(),
        success: onSuccess,
        error: onFail,
    });

}

// Shows final page
function finalPage(firstInstall) {
  var showed = "wizardPage" + visible;
  var content;
  var url;

  actualPage = pages.length; // set to the last page
  if (firstInstall) {
     url = '/SaveChanges?';
     url     += 'noPopup=1&save=1';
     url += '&firstTime=1';
  } else {
     url = '/Wizard/SoftwareSetupFinish?firstTime=0';
  }

  content = '<script type="text/javascript">';
  content += 'window.location = "' + url + '";';
  content += '</script>';

  jQuery('#' + showed).html(content);
}

