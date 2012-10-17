var DURATION = 0.5;
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
        $('wizard-loading1').show();
        $('wizard-next1').disabled = true;
        $('wizard-next2').disabled = true;
        $('wizard-skip1').disabled = true;
        $('wizard-skip2').disabled = true;
        isLoading = true;
    }
    else {
        $('wizard-loading1').hide();
        $('wizard-next1').disabled = false;
        $('wizard-next2').disabled = false;
        $('wizard-skip1').disabled = false;
        $('wizard-skip2').disabled = false;
        isLoading = false;
    }
}
window.setLoading = setLoading;

// Load a wizard page
function loadPage(index) {
    if ( index < 0 || index > pages.length ) return;

    setLoading(true);

    $('wizard_error').hide();

    var hidden = visible;
    var showed = (visible + 1) % 2;
    if ( firstLoad ) {
        showed = visible;
        firstLoad = false;
    }
    visible = showed;

    hidden = "wizardPage" + hidden;
    showed = "wizardPage" + showed;

    if ( index > 0 )
        Effect.SlideUp(hidden, { duration: DURATION } );

    // Final stage?
    if ( index >= pages.length ) {
        $('wizard-next1').hide();
        $('wizard-next2').hide();
        setLoading(false);
        finalPage(firstInstall);
        return;
    }

    var loaded = function() {
        Effect.SlideDown(showed, { duration: DURATION, queue: 'end' } );

        var form = $$('#' + showed + ' form')[0];
        // avoid automatic form submition (by enter press)
        if ( form ) {
            form.onsubmit = function() { return false; };
        }

        setLoading(false);
        if ( index == pages.length-1 ) {
          var finishString = gettext('Finish');
          $('wizard-next1').value = finishString;
          $('wizard-next2').value = finishString;
        }
    };

    new Ajax.Updater(showed,
                     pages[index],
                     {
                        method:'get',
                        onComplete: loaded,
                        evalScripts: true
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
    var form = $$('#wizardPage' + visible + ' form')[0];

    var failed = false;

    var onFail = function(response) {
        failed = true;
        $('wizard_error').update(response.responseText);
        $('wizard_error').appear({
                duration: 0.5,
                from: 0, to: 1 });

        setLoading(false);
    };

    var onComplete = function(response) {
        // Load next page
        if ( !failed )
            loadPage(actualPage+1);
    };

    form.request({
        onFailure: onFail,
        onComplete: onComplete
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

  $(showed).update(content);
}

