function switchHelp(){
	elements=getElementByClass("help");
	var inc=0;
	while (elements[inc]) {
		if(elements[inc].style.display=="block") {
			elements[inc].style.display="none";
		} else {
			elements[inc].style.display="block";
		}
		inc++;
	}

        // Toggle link text
        var show_link = document.getElementById('showhelp');
        var hide_link = document.getElementById('hidehelp');
        if (show_link.style.display != "none") {
                show_link.style.display = "none";
                hide_link.style.display = "inline";
        } else {
                hide_link.style.display = "none";
                show_link.style.display = "inline";
        }
}

elements=getElementByClass("help");

if(elements.length == 0) {
   var  helpbutton = document.getElementById("helpbutton");	
   if (helpbutton) {
	helpbutton..style.display="none";
    }
}
