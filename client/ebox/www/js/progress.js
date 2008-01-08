// code used by progress.mas

// Update the page  
function updatePage (xmlHttp) {
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
        // current item
        if (('message' in response) && response.message.length > 0 ) {
   	   $('currentItem').innerHTML = response.message;
        }

       	if ( ('ticks' in response) && (response.ticks >= 0)) {
	     $('ticks').innerHTML = response.ticks;
        }

       	if ( ('totalTicks' in response) && (response.totalTicks > 0)) {
	     $('totalTicks').innerHTML = response.totalTicks;
        }         
    }

    if (response.state == 'done') {
        Element.hide('progressing');
        if ( 'retValue' in response ) {
            if ( response.retValue == 0 ) {
                Element.show('done');
            } else {
                Element.show('error-progress');
                if ( 'errorMsg' in response ) {
                  $('error-progress-message').update( response.errorMsg );
                }
            }
        } else {
            Element.show('done');
        }
   }
}

// Generate an Ajax request to fetch the current package
function callServer(progressId, url) {
  // Build the URL to connect to
  var par = "progress=" + progressId ;

   new Ajax.Request(url, {
   			  method: 'post',
			  parameters: par,
			  asynchronous: true,
			  onSuccess: function (t) { updatePage(t) }
			 }
		    );

}


var pe;
function createPeriodicalExecuter(progressId, currentItemUrl,  reloadInterval)
{
  var callServerCurriedBody = 	"callServer(" + progressId + ", '" + currentItemUrl  + "' )";
  callServerCurried = new Function(callServerCurriedBody );

  pe = new PeriodicalExecuter(callServerCurried, reloadInterval);
}
