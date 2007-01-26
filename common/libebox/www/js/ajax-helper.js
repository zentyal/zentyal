

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

function changeRow(url, table, fields, directory, id)
{
	var pars = 'action=edit&tablename=' + table + '&directory=' + directory + '&id=' + id + '&';
	

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

function changeView(url, table, directory, action, id)
{
	var pars = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
	
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
