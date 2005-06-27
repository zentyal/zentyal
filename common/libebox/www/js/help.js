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
}

elements=getElementByClass("help");

if(elements.length == 0) {
	document.getElementById("helpbutton").style.display="none";
}
