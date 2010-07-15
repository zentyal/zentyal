// code used by progress.mas
var percent = 0;
var oldPercent = 0;
var time = 0;

// Update the page  
function updatePage (xmlHttp, nextStepTimeout, nextStepUrl) {
    var rawResponse = xmlHttp.responseText;
    var rawSections = rawResponse.split(",");

   var response = {};
   for  (var i=0; i < rawSections.length; i++ ) {
       var parts = rawSections[i].split(":");
       var name  = parts[0];
       var value = parts[1] ;
       response[name]  = value;
   }
   


    if (xmlHttp.readyState == 4) {
	if (response.state == 'running') {
		// current item
		 if (('message' in response) && response.message.length > 0 ) {
			$('currentItem').innerHTML = response.message;
		}
	    
		 if ( ('ticks' in response) && (response.ticks >= 0)) {
			$('ticks').innerHTML = response.ticks;
			var ticks = response.ticks;
		}	    
		if ( ('totalTicks' in response) && (response.totalTicks > 0)) {
			$('totalTicks').innerHTML = response.totalTicks;
			var totalTicks = response.totalTicks;
		}
		percent = Math.ceil((ticks/totalTicks)*100);
		ph.setValue(percent);
	}
    
       else if (response.state == 'done') {
                Element.hide('progressing');
                Element.show('done');

                if ( nextStepTimeout > 0 ) {
                    setTimeout ( "location.href='" + nextStepUrl + "';", nextStepTimeout*1000 );
                }

                // Used to tell selenium we are done
                // with saving changes
                $('ajax_request_cookie').value = 1337;
       }
       else if (response.state == 'error') {
              Element.hide('progressing');
              Element.show('error-progress');
             if ( 'errorMsg' in response ) {
                       $('error-progress-message').update( response.errorMsg );
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
  if ((time >= 9) & ((percent-oldPercent) > 8)) {
	  time = 0;
	  oldPercent = percent;
	  showAds();
  }
	

}


var pe;
function createPeriodicalExecuter(progressId, currentItemUrl,  reloadInterval, nextStepTimeout, nextStepUrl)
{
  var callServerCurriedBody = 	"callServer(" + progressId + ", '"
                                              + currentItemUrl  + "', "
                                              + nextStepTimeout + ", '"
                                              + nextStepUrl + "')";

  callServerCurried = new Function(callServerCurriedBody );

  pe = new PeriodicalExecuter(callServerCurried, reloadInterval);
}
