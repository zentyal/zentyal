function newInPlaceEditor(id, url, table, leading_text, fields, skipField, directory) {
	var params = parsUrl(leading_text, fields, skipField);

	new Ajax.InPlaceEditor
			(
				leading_text + skipField,
				url,
				{
					callback: function ( form, value ) 
					{
						$('error_' + table).innerHTML = '';

						return params +
						'&action=edit&editfield=' +
						skipField + '&id=' + id + '&' +
						"tablename=" + table +
						"&directory=" + directory + '&' + skipField + '=' + value;
					},
					onFailure: function (response) { $('error_' + table).innerHTML = response.responseText;}
				}

			);

}

function sendCheckboxChange(id, url, table, leading_text, fields, skipField, directory ) {
	var params = parsUrl(leading_text, fields, '');
	params = 'action=edit&editfield=' + skipField + '&id=' + id +
	'&directory='  + directory + '&tablename=' + table + '&' + params;

	var myAjax = new Ajax.Request
			(
				url,
				{
					method: 'post',
					parameters: params,
					onComplete: function(res) 
								{
									receiveCheckboxChange(res, table, 
											leading_text + skipField)
								}
				}
			);

	
}

function receiveCheckboxChange(res, table, field)
{
	var element = $(field);

	$('error_' + table).innerHTML = "";

	if (res.status == 200) {
		alert('status 200');
		return;
	}

	if (element.checked) {
		element.checked = false;
	} else {
		element.checked = true;
	}	

	$('error_' + table).innerHTML = res.responseText;

}

function sendSelectChange(id, url, table, leading_text, fields, editField) {
	var params = parsUrl(leading_text, fields, '');
	params = 'action=edit&editfield=' + editField + '&id=' + id + 
	'&directory='  + directory + '&tablename=' + table + '&' + params;

	var myAjax = new Ajax.Request
			(
				url,
				{
					method: 'post',
					parameters: params,
					onComplete: function(res) 
								{
									receiveSelectChange(res, table, 
											leading_text + skipField)
								}
				}
			);

	
}

function receiveSelectChange(res, table, field)
{
	$('error_' + table).innerHTML = "";

	if (res.status == 200) {
		alert('status 200');
		return;
	}

	$('error_' + table).innerHTML = res.responseText;

}



function parsUrl(leading_text, fields, skipField) {
	var pars = '';

	for (var i = 0; i < fields.length; i++) {
		var field = fields[i];
		
		/* Should we skip this field */
		if (field == skipField) {
			continue;
		}
		
		var value = '';
		var node = $(leading_text + field);

		/* If node does not exist we skip */
		if (!node) {
			continue;
		}

		/* What kind of node are we dealing with?
		 * 
		 * if checkbox 
		 * 
		 * if select
		 *
		 * else we get the html contained
		 */
		if (node.type == 'checkbox') {
			if (node.checked) {
					value = '1';
			} else {
				continue;
			}
		} else if (node.type == 'select-one') {
			value = node.value;
		} else {
			value = node.innerHTML;
		}
		

		if (value) {
			if (pars.length != 0) {
				pars += '&';
			}
			pars += field + '=' + value;
		}
		//alert(field + ': ' + value);
	}

	//alert(pars);
	return pars;
}

function addNewRow(url, table, fields, directory)
{
	var pars = 'action=add&tablename=' + table + '&directory=' + directory + '&';
	

	for (var i = 0; i < fields.length; i++) {
		var field = fields[i];
		var value = $F(table + '_' + field);
		if (value) {
			if (pars.length != 0) {
				pars += '&';
			}
			pars += field + '=' + value;
		}
	}

	var MyAjax = new Ajax.Updater(
		{
			success: table,
			failure: 'error_' + table 
		},
		url,
		{
			method: 'post',
			parameters: pars,
			asyncrhonous: false,
			evalScripts: true,
			onComplete: function(t) { stripe('dataTable', '#ecf5da', '#ffffff'); }
		});
}

function actionClicked(url, table, pars, directory) {
	pars = pars +  '&directory=' + directory + '&tablename=' + table;

	alert(pars);
	var MyAjax = new Ajax.Updater(
	    {
		success: table,
		failure: 'error_' + table 
	    },
	    url,
	    {
		method: 'post',
		parameters: pars,
		asyncrhonous: false,
		evalScripts: true,
		onComplete: function(t) {stripe('dataTable', '#ecf5da', '#ffffff'); }
	    });

}
