"use strict";
jQuery.noConflict();
Zentyal.namespace('Wizard.Software');

Zentyal.Wizard.Software.DURATION = 500;
Zentyal.Wizard.Software.actualPage = 0;
Zentyal.Wizard.Software.visible = 0;
Zentyal.Wizard.Software.firstLoad = true;
Zentyal.Wizard.Software.firstInstall = false;
Zentyal.Wizard.Software.isLoading = false;
Zentyal.Wizard.Software.pages = null;
Zentyal.Wizard.Software.gettext = null;

Zentyal.Wizard.Software.setPages = function(newPages) {
  Zentyal.Wizard.Software.pages = newPages;
};


Zentyal.Wizard.Software.setFirstInstall = function(first) {
  Zentyal.Wizard.Software.firstInstall = first;
};

Zentyal.Wizard.Software.setGettext = function(gett) {
  Zentyal.Wizard.Software.gettext = gett;
};

// enable/disable next step buttons
Zentyal.Wizard.Software.setLoading = function(loading) {
    if (loading) {
        // Disable more clicks
        jQuery('#wizard-loading1').show(0);
        jQuery('button').attr('disabled','disabled').hide(0);
        Zentyal.Wizard.Software.isLoading = true;
    } else {
        jQuery('#wizard-loading1').hide(0);
        jQuery('button').removeAttr('disabled').show(0);
        Zentyal.Wizard.Software.isLoading = false;
    }
};

// Load a wizard page
Zentyal.Wizard.Software.loadPage = function(index) {
    if ( index < 0 || index > Zentyal.Wizard.Software.pages.length ) return;

    Zentyal.Wizard.Software.setLoading(true);

    jQuery('#wizard_error').hide(0).html('');

    var hiddenNumber = Zentyal.Wizard.Software.visible;
    var showedNumber = (Zentyal.Wizard.Software.visible + 1) % 2;
    if ( Zentyal.Wizard.Software.firstLoad ) {
        showedNumber = Zentyal.Wizard.Software.visible;
        Zentyal.Wizard.Software.firstLoad = false;
    }
    Zentyal.Wizard.Software.visible = showedNumber;

    if ( index > 0 ) {
        jQuery("#wizardPage" + hiddenNumber).slideUp(Zentyal.Wizard.Software.DURATION);
    }

    // Final stage?
    if ( index >= Zentyal.Wizard.Software.pages.length ) {
        jQuery('#wizard-next1').hide(0);
        jQuery('#wizard-next2').hide(0);
        Zentyal.Wizard.Software.setLoading(false);
        Zentyal.Wizard.Software.finalPage(Zentyal.Wizard.Software.firstInstall);
        return;
    }

    var loaded = function(code) {
        var showed = jQuery("#wizardPage" + showedNumber);
        showed.show(0).html(code).slideDown(Zentyal.Wizard.Software.DURATION);
        var form = jQuery('#wizardPage' + showedNumber + ' form')[0];
        // avoid automatic form submition (by enter press)
        if ( form ) {
            jQuery(form).submit(function() { return false; });
        }

        Zentyal.Wizard.Software.setLoading(false);
        if ( index == Zentyal.Wizard.Software.pages.length-1 ) {
            var finishString = Zentyal.Wizard.Software.gettext('Finish');
            jQuery('#wizard-next1')[0].value = finishString;
            jQuery('#wizard-next2')[0].value = finishString;
        }
    };

    jQuery.ajax({
        url: Zentyal.Wizard.Software.pages[index],
        dataType: 'html',
        success: loaded
    });
    Zentyal.Wizard.Software.actualPage = index;
};

// Skip this page
Zentyal.Wizard.Software.skipStep = function() {
    Zentyal.Wizard.Software.loadPage(Zentyal.Wizard.Software.actualPage+1);
};

// Save changes and step into next page
Zentyal.Wizard.Software.nextStep = function() {
    // avoid possible mess by page calls to this function
    if (Zentyal.Wizard.Software.isLoading) {
        return;
    }
    Zentyal.Wizard.Software.setLoading(true);
    // Submit form
    var form = jQuery('#wizardPage' + Zentyal.Wizard.Software.visible + ' form');
    var error = function(response) {
        jQuery('#wizard_error').show(0).html(response.responseText).fadeIn();
        Zentyal.Wizard.Software.setLoading(false);
    };
    var success = function(response) {
        Zentyal.Wizard.Software.loadPage(Zentyal.Wizard.Software.actualPage+1);
    };

    jQuery.ajax({
        url: form.attr('action'),
        type: 'POST',
        data: form.serialize(),
        success: success,
        error: error
    });

};

// Shows final page
Zentyal.Wizard.Software.finalPage = function(firstTime) {
  var showed = "wizardPage" + Zentyal.Wizard.Software.visible;
  var content;
  var url;

  Zentyal.Wizard.Software.actualPage = Zentyal.Wizard.Software.pages.length; // set to the last page
  if (firstTime) {
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
};

