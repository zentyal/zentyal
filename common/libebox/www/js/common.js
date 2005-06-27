function getElementByClass(classname) {
	ccollect=new Array()
	var inc=0;
	var alltags=document.getElementsByTagName("*");
	for (i=0; i<alltags.length; i++){
		if (alltags[i].className==classname)
			ccollect[inc++]=alltags[i];
	}
	return ccollect;
}

function setDefault(){
	elements=getElementByClass("hide");
	var inc=0;
	while (elements[inc]){
		elements[inc].style.display="none";
		inc++;
	}
	inc=0;
	elements=getElementByClass("show");
	while (elements[inc]){
		elements[inc].style.display="inline";
		inc++;
	}
}

function show(id){
	setDefault();
	document.getElementById(id).style.display="block";
	document.getElementById("hideview" + id).style.display="none";
	document.getElementById("showview" + id).style.display="inline";
}

function hide(id){
	setDefault();
}

var shownMenu = "";

function showMenu(name){
	var inc;
	if(shownMenu.length != 0) {
		elements=getElementByClass(shownMenu);
		inc=0;
		while (elements[inc]){
			elements[inc].style.display="none";
			inc++;
		}
	}

	elements=getElementByClass(name);
	inc=0;
	while (elements[inc]){
		elements[inc].style.display="block";
		inc++;
	}
	shownMenu = name;
}


function checkAll(id){
	form=document.getElementById(id);
	for (var i=0;i<form.elements.length;i++)
	{
		var e=form.elements[i];
		if ((e.name != 'allbox') && (e.type=='checkbox')) {
			e.checked=form.allbox.checked;
		}
	}
}
