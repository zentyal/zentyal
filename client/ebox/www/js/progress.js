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
	if (response.state == 'running') {
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
    
       else if (response.state == 'done') {
                Element.hide('progressing');
                Element.show('done');
                // Used to tell selenium we are done
                // with saving changes
                $('ajax_request_cookie').value = 0;
       }
       else if (response.state == 'error') {
              Element.hide('progressing');
              Element.show('error-progress');
             if ( 'errorMsg' in response ) {
                       $('error-progress-message').update( response.errorMsg );
             }
      }


	if (response.changed) {
           // change 'Save Changes' menu to reflect possible changes		
           var finishClass = response.changed;
           var finishAnchor = document.getElementById('changes_menu');
           finishAnchor.className = finishClass;
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
