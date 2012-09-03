var DURATION = 0.5;
var actualPage = 0;
var visible = 0;
var firstLoad = true;
var firstInstall = false;
var isLoading = false;
var pages = null;



function setPages(newPages)
{
  pages = newPages;
}

function setFirstInstall(first)
{
  firstInstall = first;
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
    if ( index == pages.length ) {
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
          // XXX gettext
            $('wizard-next1').value = "<% __('Finish') %>";
            $('wizard-next2').value = "<% __('Finish') %>";
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
    var actualPage = pages.length;
    var showed = "wizardPage" + visible;
    var content;
  if (firstInstall) {
    var url = '/EBox/SaveChanges?';
    url     += 'firstTime=1&noPopup=1';
    content = '<script type="text/javascript">';
    content += 'window.location = "' + url + ';"';
    content += '</script>';
 } else {
    content = '<div style="text-align: center; padding: 40px">';
    content += '<div><img src="<% $image_title %>" alt="title" /></div>';

   // XX getext
//    content += '<h4><% __('Package installation finished') %></h4>';
//    content += '<div><% __('Now you are ready to enable and configure your new
//    installed modules') %></div>';
    content += '<h4>Package installation finished</h4>';
    content += '<div>Now you are ready to enable and configure your new  installed modules</div>';



    content += '<form  method="POST">';
   // XXX getext
//    content += '<input style="margin: 20px; font-size: 1.4em" class="inputButton" type="submit" name="save" value="<% __('Go to the dashboard') %>"';
    content += '<input style="margin: 20px; font-size: 1.4em" class="inputButton" type="submit" name="save" value="Go to the dashboard"';
    content += " onclick=\"window.location='/Dashboard/Index'; return false\" ";
    content += ' />';
    content += '</form>';
    content += '</div>';

    }
    $(showed).update(content);
    Effect.SlideDown(showed, { duration: DURATION, queue: 'end' } );

    $('wizard-skip1').hide();
    $('wizard-skip2').hide();
}

