"use strict";

Zentyal.namespace('Wizard.Software');

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
        $('#wizard-loading1').show(0);
        $('button').attr('disabled','disabled').hide(0);
        Zentyal.Wizard.Software.isLoading = true;
    } else {
        $('#wizard-loading1').hide(0);
        $('button').removeAttr('disabled').show(0);
        Zentyal.Wizard.Software.isLoading = false;
    }
};

// Load a wizard page
Zentyal.Wizard.Software.loadPage = function(index) {
    if ( index < 0 || index > Zentyal.Wizard.Software.pages.length ) return;

    Zentyal.Wizard.Software.setLoading(true);

    $('#wizard_error').hide(0).html('');

    var hiddenNumber = Zentyal.Wizard.Software.visible;
    var showedNumber = (Zentyal.Wizard.Software.visible + 1) % 2;
    if ( Zentyal.Wizard.Software.firstLoad ) {
        showedNumber = Zentyal.Wizard.Software.visible;
        Zentyal.Wizard.Software.firstLoad = false;
    }
    Zentyal.Wizard.Software.visible = showedNumber;

    if ( index > 0 ) {
        $("#wizardPage" + hiddenNumber).hide();
    }

    // Final stage?
    if ( index >= Zentyal.Wizard.Software.pages.length ) {
        $('#wizard-next1').hide(0);
        $('#wizard-next2').hide(0);
        Zentyal.Wizard.Software.setLoading(false);
        Zentyal.Wizard.Software.finalPage(Zentyal.Wizard.Software.firstInstall);
        return;
    }

    var loaded = function(code) {
        var showed = $("#wizardPage" + showedNumber);
        showed.show(0).html(code).show();
        var form = $('#wizardPage' + showedNumber + ' form')[0];
        // avoid automatic form submission (by enter press)
        if ( form ) {
            $(form).submit(function() { return false; });
        }

        Zentyal.Wizard.Software.setLoading(false);
        if ( index == Zentyal.Wizard.Software.pages.length-1 ) {
            var finishString = Zentyal.Wizard.Software.gettext('Finish');
            $('#wizard-next1').val(finishString);
            $('#wizard-next2').val(finishString);
        }
    };

    $.ajax({
        url: Zentyal.Wizard.Software.pages[index],
        dataType: 'html',
        success: loaded
    });
    Zentyal.Wizard.Software.actualPage = index;
};

// Skip this page
Zentyal.Wizard.Software.skipStep = function() {
    var form = $('#wizardPage' + Zentyal.Wizard.Software.visible + ' form');
    var url = form.attr('action');
    var data = 'skip=1';
    Zentyal.Wizard.submitPage(url, data);
};

// Save changes and step into next page
Zentyal.Wizard.Software.nextStep = function() {
    var form = $('#wizardPage' + Zentyal.Wizard.Software.visible + ' form');
    var url = form.attr('action');
    var data =  form.serialize();
    Zentyal.Wizard.submitPage(url, data);
};

Zentyal.Wizard.submitPage = function (url, data) {
    // avoid possible mess by page calls to this function
    if (Zentyal.Wizard.Software.isLoading) {
        return;
    }
    Zentyal.Wizard.Software.setLoading(true);
    // Submit form
    var form = $('#wizardPage' + Zentyal.Wizard.Software.visible + ' form');
    var error = function(response) {
        $('#wizard_error').show(0).html(response.responseText).fadeIn();
        Zentyal.Wizard.Software.setLoading(false);
    };
    var success = function(response) {
        Zentyal.Wizard.Software.loadPage(Zentyal.Wizard.Software.actualPage+1);
    };

    $.ajax({
        url: url,
        type: 'POST',
        data: data,
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

  $('#' + showed).html(content);
};

