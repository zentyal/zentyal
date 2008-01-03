/* 
   This bunch of function are JS function to improve the development
   of /ajax/image.mas template.
*/

function reloadGraph(url, target, tableName, directory, action)
{


	var pars = 'action=' + action + '&tablename=' + target + '&directory=' + directory; //+ '&editid=' + id;

        cleanError(tableName);
	
	var MyAjax = new Ajax.Updater(
		{
			success: target,
			failure: target,
		},
		url,
		{
			method: 'post',
			parameters: pars,
			asyncrhonous: false,
			evalScripts: true,
			onComplete: function(t) { 
			  stripe('dataTable', '#ecf5da', '#ffffff');

			},
		});

}

function switchImg(hiddenPrefix, activePrefix)
{
     var hiddenImgId = hiddenPrefix + 'Img';
     var hiddenDivId = hiddenPrefix + 'Div';
     var activeImgId = activePrefix + 'Img';
     var activeDivId = activePrefix + 'Div';

     var oldHiddenImg = $(hiddenImgId);
     var oldHiddenDiv = $(hiddenDivId);
     var oldActiveImg = $(activeImgId);
     var oldActiveDiv = $(activeDivId);

     oldHiddenImg.id = activeImgId;
     oldHiddenDiv.id = activeDivId;   
     oldActiveImg.id = hiddenImgId;
     oldActiveDiv.id = hiddenDivId;   

     Element.setStyle( oldActiveDiv, {   position: 'absolute', display: 'none'});
     Element.setStyle( oldHiddenDiv, {   position: 'absolute', display : 'block' });
     Element.setStyle( oldActiveImg, {   position: 'absolute', display: 'none'});
     Element.setStyle( oldHiddenImg, {   position: 'absolute', display: 'block' });

     var hiddenImgOnload = oldHiddenDiv.onload;
     oldHiddenDiv.onload = '';
//   oldActiveDiv = hiddenImgOnload;
     oldActiveDiv.onload = hiddenImgOnload;

     // Set the correct heigth to the white background image
     var imgHeight = oldHiddenImg.getHeight();
     var backgroundImg = document.createElement('IMG');
     backgroundImg.setAttribute( 'height', imgHeight);
     backgroundImg.setAttribute( 'src'   , '/data/images/bkgwhite.png');
     backgroundImg.setAttribute( 'id'    , 'whiteBkgImg');
     var imgElements = oldHiddenDiv.parentNode.getElementsByTagName('img');
     
     // If only contains the hidden and active images appended
     if ( imgElements.length < 3 ) {
       oldHiddenDiv.parentNode.appendChild(backgroundImg);
     } else {
       oldHiddenDiv.parentNode.replaceChild(backgroundImg,
                                            imgElements[imgElements.length - 1]);
     }                                           

}
