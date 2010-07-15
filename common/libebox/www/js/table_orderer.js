// Copyright (c) 2007 Gregory SCHURGAST (http://www.negko.com, http://prototools.negko.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// VERSION 1.2.20090611

var TableOrderer = Class.create();
//defining the rest of the class implementation

TableOrderer.prototype = {
	initialize: function(element,options) {
		this.element = element;
		this.options = options;
		
		this.options = Object.extend({
			data: false, 				// array of data
			url: false, 				// url to a JSON application containing the data
			allowMultiselect : true, 	// don't work yet
			unsortedColumn : [],		// array of column you don't want to sort
			dateFormat : 'd', 			// d|m ; d => dd/mm/yyyy; m => mm/dd/yyyy
			filter : false,				// show Filter Option. false | 'top' | 'bottom'
			pageCount : 5,				// Number of items by table 
			paginate : false,		    // show Paginate Option. false | 'top' | 'bottom'
			search : false				// show Gloabal Search . falses | 'top' | 'bottom'
		}, options || {});
		
		// saves tool state data for pagination, filtering and searching. 
		this.tools = {
			page: 1,					// for pagination
			pages: 1,					// for pagination
			filterCol: '',				// for filtering
			filterData: '',				// for filtering
			searchData: ''				// for global searching
		};
		
		// separates text messages out 
		this.msgs = {
			loading: 'Loading...',
			emptyResults: 'No matches found',
			errorURL: 'invalid data',
			errorData: 'no data',
			searchLabel: 'Search : ',
			filterLabel: 'Filter Column : ',
			paginationOf: ' of ',
			paginationPages: ' pages ',
			paginationFirst: '<<',
			paginationPrev: '<',
			paginationNext: '>',
			paginationLast: '>>'
		};
		
		this.cache = [];				// for caching capabilities
		this.isCached = false;			// for caching capabilities
		this.container = $(element);
		this.orderField = false;
		this.order = 'asc';	
		this.thClickbfx = this.thClick.bindAsEventListener(this);
		this.thOverbfx = this.thOver.bindAsEventListener(this);
		this.thOutbfx = this.thOut.bindAsEventListener(this);
		this.setData();
		
	},
	
	// clearCache -- Replaces this.cache with orginal data loaded into the table.
	clearCache : function() {
		this.isCached = false;
		this.cache = this.data;
		
		// Clearing the cache does not clear any ordering done on the data, 
		// just operations that remove records from the user's view (i.e. filtering)
		if(this.orderField) {
			this.orderData(this.orderField);
			if (this.order == 'desc') { this.cache = this.cache.reverse(); }
		} 
	},
	
	// preform -- performs any inital operations needed to create the table after the data has been loaded.
	perform : function(){
		this.tools.pages = Math.ceil(this.cache.size() / this.options.pageCount);
		this.setColumnsName();
		this.clearCache();
		this.createTable();
	},
	
	// getData -- gets table data from a @url. The header response from the URL must be application/json
	// param url: URL from where the total table data resides.
	getData : function(url){
		var transmit = new Ajax.Request(url,{
			onLoading : function(){ $(this.element).update(this.msgs.loading); }.bind(this),
			onSuccess: function(transport) {
				this.data = transport.responseJSON;
				this.perform();
			}.bind(this),
			onFailure : function(){ alert(this.msgs.errorURL); }
		});
	},
	
	// setData -- determines if the data is coming from a URL or from a json string on the page.
	setData : function(){
		if (!this.options.data && !this.options.url){alert(this.msgs.errorData);}
		this.data = this.options.data ? this.options.data : false;
		if(this.data) { this.perform(); } else { this.getData(this.options.url); }
	},

	// orderRule -- determines if @s is a date
	// param s: string representing column data
	orderRule : function (s){
		var dateRE = /^(\d{2})[\/\- ](\d{2})[\/\- ](\d{4}|\d{2})/;
		var exp=new RegExp(dateRE);
		if ( exp.test(s) ){
			s = this.options.dateFormat == 'd' ? s.replace(dateRE,"$3$2$1") : s.replace(dateRE,"$3$1$2");
		}
		return s;
	},
	
	// defineOrderField -- keeps track of previous orderField columns and sets the current orderField through the triggering element's id.
	// param e: the event object created that triggered this method
	defineOrderField : function(e){
		this.previousOrderField = this.orderField; 
		this.orderField = Event.element(e).id.replace(this.table.id+'-','');
	},

	/*  if you click on a header for the first time order is ascending
	     else it switches between ascending and descending
	*/
	// defineOrder -- determines what the order of the data should be
	defineOrder : function(){ 
		if (this.previousOrderField == this.orderField){ this.order = this.order == 'desc' ? 'asc' : 'desc'; }
		else { this.order = 'asc'; }
	},
	
	/* Ordonne les données du tableau */
	// orderData -- sorts the table's cache by the @order given it.
	// param order: defines the order that the data should be as ascending (asc) or descending (desc)
	orderData : function(order){
		this.cache = this.cache.sortBy(function(s){
			var v = Object.values(s)[Object.keys(s).indexOf(order)];
			return this.orderRule(v);
		}.bind(this));
	},
	
	// thClick -- event handler for when the user clicks on the th cell of the table. It orders the table data by that column's field.
	// param e: event that triggered handler.
	thClick : function(e){
		this.defineOrderField(e);
		this.defineOrder();
		this.orderData(this.orderField);
		
		if (this.order == 'desc') { this.cache = this.cache.reverse(); }
		
		this.updateTable();
	},
	
	// thOver -- event handler for when the user's mouse goes over the th cell.
	// param e: event that triggered handler
	thOver : function(e){
		Event.element(e).addClassName('on');
	},
	
	// thOut -- event handler for when the user's mouse moves out of the th cell.
	// param e: event that triggered handler
	thOut : function(e){
		Event.element(e).removeClassName('on');
	},
		
	// trClick -- event handler for when user clicks on a table row, highlighting the row
	// param e: event that triggered handler
	trClick : function(e){
		this.setSelected(Event.findElement(e,'tr'));
		var selected;
		var items = Event.findElement(e,'tr').descendants().pluck('innerHTML');
		var json = '{';
		var keys  = Object.keys(this.model);
		
		items.each(function(i,index){
			json += index === 0 ? '' : ', '; 
			json += '"'+keys[index]+'": "'+i+'"';
		});
		json += '}';
		selected = json.evalJSON();
	},
	
	// trOver -- event handler for when the user's mouse moves into a table row.
	// param e: event that triggered handler
	trOver : function(e){
		Event.findElement(e,'tr').addClassName('on');
	},
	
	// trOut -- event handler for when the user's mouse moves out of a table row.
	// param e: event that triggered handler
	trOut : function(e){
		Event.findElement(e,'tr').removeClassName('on');
	},
	
	// setSelected -- what to do when a table row is selected.
	// param elt: the table row that is selected
	setSelected : function(elt){
		if (this.options.allowMultiselect){
			if(elt.hasClassName('selected')) { elt.removeClassName('selected'); } else { elt.addClassName('selected'); }
		}
		else{
		/* */
		}
	},

	// addToolsObserver -- binds the event handlers to the events associated with tools only
	addToolsObserver : function(){
		var tid = this.table.id;

		if (this.options.filter){
			var filterDatakbfx = this.filterData.bindAsEventListener(this);
			Event.observe(tid+'-filter-column','change',filterDatakbfx);
			Event.observe(tid+'-filter-data','keyup',filterDatakbfx);
		}

		if (this.options.search){
			var searchDatakbfx = this.searchData.bindAsEventListener(this);
			Event.observe(tid+'-search-data','keyup',searchDatakbfx);
		}
		
		if(this.options.paginate){
			var pagerDatabfx = this.pagerData.bindAsEventListener(this);
			Event.observe(tid + '-page-prev', 'click', pagerDatabfx);
			Event.observe(tid + '-page-next', 'click', pagerDatabfx);
			Event.observe(tid + '-page-last', 'click', pagerDatabfx);
			Event.observe(tid + '-page-first', 'click', pagerDatabfx);
		}
	},
	
	// addTableObserver -- binds event handlers to the events associated with the table generated.
	addTableObserver : function() {
		var tid = this.table.id;
		$$('#'+tid+' th')
			.invoke('observe','click',this.thClickbfx)
			.invoke('observe','mouseover',this.thOverbfx)
			.invoke('observe','mouseout',this.thOutbfx);
		
		$$('#'+tid+' tr.data')
			.invoke('observe','click',this.trClick.bindAsEventListener(this))
			.invoke('observe','mouseover',this.trOver.bindAsEventListener(this))
			.invoke('observe','mouseout',this.trOut.bindAsEventListener(this));
	},
	
	// Two approaches to filtering:
	// 1. If pagination is turned ON then we just recreate the rows using updateTable. Somewhat costly due to creating new elements but hopefully offset by a smaller amount of rows being shown.
	// 2. If pagination is turned OFF then go the slick way of just hiding the rows, which is much faster.
	//
	// filterData -- handler for filtering data. Updates this.tools internal state information for the filter tool and updates the table. Tried optimizing it as much as possible.
	// param e: the event triggering handler
	filterData : function(e){
		var tid = this.table.id;
		var caller = Event.element(e);
		
		if(caller.id == tid + '-filter-column' && this.tools.filterData === ''){
			this.tools.filterCol = $F(tid + '-filter-column');
			return; // if we are just changing the column option and we had not filtered previously then just update the column info.
		}
		
		// Update state information for filter tool.
		this.tools.filterData = $F(tid + '-filter-data');
		if(caller.id == tid + '-filter-column') {
			// clear filter data when changing which column we are filtering on.
			$(tid + '-filter-data').clear();
			this.tools.filterCol = $F(tid + '-filter-column');
			this.tools.filterData = '';
		}

		// Anytime we filter there is a good chance our data view will change.
		this.clearCache();
		
		if(this.options.paginate) {
			this.updateTable();
			return;
		}

		$$('#'+tid+' td.' + tid+'-column-'+this.tools.filterCol).each(function(i){
			i.ancestors()[1].show();
			if(!i.innerHTML.toUpperCase().include(this.tools.filterData.toUpperCase())){
				i.ancestors()[1].hide();
			}
		});
	},

	// pagerData -- handler for pagination. This is modifies the internal state of this.tools for pagination and then updates the table. It supports first, last, next and previous operations on the pages.
	// param e: the event that triggered the handler
	pagerData : function(e){
		var tid = this.table.id;
		var caller = Event.element(e);
		
		switch(caller.id) {
			case tid+'-page-next':
				this.tools.page = ((++this.tools.page) > this.tools.pages) ? --this.tools.page : this.tools.page;
			break;
			case tid+'-page-prev':
				this.tools.page = ((--this.tools.page) > this.tools.pages) ? ++this.tools.page : this.tools.page;
			break;
			case tid+'-page-last':
				this.tools.page = this.tools.pages;
			break;
			default:
				this.tools.page = 1;
		}
		this.updateTable();
	},

	// searchData -- handler for search tool. This modifies the internal state of this.tools for search tool, clears the cache and updates the table.
	// param e: the event that triggered the handler
	searchData : function(e){
		var tid = this.table.id;
		
		// Update state information for search tool.
		this.tools.searchData = $F(tid + '-search-data');

		// Anytime we filter there is a good chance our data view will change.
		this.clearCache();
		
		this.updateTable();
	},
	
	// makeColumnUnsortable -- takes the @columnId and makes its associated th cell unclickable by removing  any user visual cue that it is a sortable column
	// param columnId: the name of the column (field) that will be unsortable. This the same name that is used as part of the column's id.
	makeColumnUnsortable : function(columnId){
		columnId = this.table.id + '-' + columnId;
		$(columnId).setStyle({'backgroundImage' : 'none'});
		Event.stopObserving($(columnId),'click', this.thClickbfx);
		Event.stopObserving($(columnId),'mouseover', this.thOverbfx);
		Event.stopObserving($(columnId),'mouseout', this.thOutbfx);
	},
	
	// makeUnsort -- cycles through each item of options.unsortedColumn and makes them unsortable.
	makeUnsort : function(){
		this.options.unsortedColumn.each(function(i){
			if($(this.table.id + '-' + i)){ this.makeColumnUnsortable(i);}
		}.bind(this));
	},
	
	// createTable -- creates the inital table being ran just once. It writes out the HTML elements for the table and tools interface (i.e. pagination).
	createTable : function(){
		this.container.update();
		this.container.insert({ top: '<table cellspacing="1" cellpadding="0" id="data-grid-'+this.element+'" class="prototools-table"></table>' });
		this.table = $('data-grid-'+this.element);
		this.createTools();
		this.createRows();
		this.addToolsObserver();
		this.addTableObserver();
		this.makeUnsort();
	},
	
	// updateTable -- updates just the table data, writting out the updated rows to the user and recreating the th cells in the process.
	updateTable : function(){
		this.table = $('data-grid-'+this.element);
		$(this.table.id).update();
		this.createRows();
		this.addTableObserver();
		this.makeUnsort();
	},
	
	// createRow -- writes out the HTML for a row using the data in @obj and applies the correct class styles associated with its @index
	// param obj: holdes the data of the row
	// param index: which index row this obj is in context to the table
	createRow : function(obj,index){
		var line = index % 2;
		var row = '<tr class="data line'+line+'" id="'+this.table.id+'-'+index+'">\n';
		var values = Object.values(obj);
		
		this.tableColumnsName.each(function(s,index){
			row += '\t<td class="'+this.table.id+'-column-'+s+'">'+values[index]+'</td>\n';
		}.bind(this));
		row += '\n</tr>';
		return row;
	},
	
	// createFirstRow -- sets up the th cells of the table
	// param obj: This has not been implemented -- FOR FUTURE USE
	createFirstRow : function(obj){
		var row = '<tr>\n';
		this.tableColumnsName.each(function(i){
			row += '\t<th id="'+this.table.id+'-'+i+'">'+i.replace('_',' ').capitalize()+'</th>';
		}.bind(this));
		row += '\n</tr>';
		this.model = Object.clone(obj);		// NOT SURE WHAT THIS IS DOING.
		return row;
	},
	
	// setColumnsName -- column names come from the labels in the data given to the table. Just grab the names from the first record.
	setColumnsName : function(){
		this.tableColumnsName = Object.keys(this.data[0]);
	},
	
	// creatFilter -- creates the HTML elements for the filter tool.
	createFilter : function(){
		var option = '';
		this.tableColumnsName.each(function(i){
			option += '\t<option value="'+i+'">'+i.replace('_',' ').capitalize()+'</option>\n';
		});
		$(this.table.id+'-options').insert({bottom : this.msgs.filterLabel})
		.insert({bottom : '<select id="'+this.table.id+'-filter-column">'+option+'</select>'})
		.insert({bottom : Element('input',{'id' : this.table.id+'-filter-data'})});
		
		this.tools.filterCol = $F(this.table.id + '-filter-column');
		this.tools.filterData = $F(this.table.id + '-filter-data');
	},
	
	// createPager -- creates the HTML elements for the pagination tool
	createPager : function () {
		$(this.table.id+'-pager').insert({bottom : Element('input',{'id' : this.table.id+'-page-first', 'type' : 'button', 'value' : this.msgs.paginationFirst, 'class' : 'first-page-button'})})
		.insert({bottom : Element('input',{'id' : this.table.id+'-page-prev', 'type' : 'button', 'value' : this.msgs.paginationPrev, 'class' : 'prev-page-button'})})
		.insert({bottom : '<span id="' + this.table.id+'-page-current' + '" class="currentpage">' + this.tools.page + '</span>'})
		.insert({bottom : Element('input',{'id' : this.table.id+'-page-next', 'type' : 'button', 'value' : this.msgs.paginationNext, 'class' : 'next-page-button'})})
		.insert({bottom : Element('input',{'id' : this.table.id+'-page-last', 'type' : 'button', 'value' : this.msgs.paginationLast, 'class' : 'last-page-button'})})
		.insert({bottom : this.msgs.paginationOf + '<span id="' + this.table.id + '-page-total' + '" class="totalpages">' + this.tools.pages + '</span>' + this.msgs.paginationPages});
	},

	// createSearch -- creates the HTML elements for the search tool
	createSearch : function(){
		$(this.table.id+'-search').insert({bottom : this.msgs.searchLabel})
		.insert({bottom : Element('input',{'id' : this.table.id+'-search-data'})});
		
		this.tools.searchData = $F(this.table.id + '-search-data');
	},
	
	// A tool is any interface that acts on the table data and not directly placed in the table that is generated.
	//
	// createTools -- determines if each tool is going to be displayed at all or at the top or bottom of the data table. 
	// this should be ran only once when the table is first created since it can be expensive to create HTML elements. 
	// all other times tools are updated using DOM calls. the order that each tool appears is based on where in the code it is create here.
	createTools : function() {
		var filterDiv, pagerDiv, searchDiv;
		
		if (this.options.filter) {
			filterDiv = new Element('div' , {'id' : this.table.id+'-options' , 'class':'prototools-options'});
			if(this.options.filter == 'top') {
				this.table.insert({ before :  filterDiv});
				filterDiv.setStyle('border-bottom : none;');			
			}
			else {
				this.table.insert({ after :  filterDiv});
				filterDiv.setStyle('border-top : none;');			
			}
			this.createFilter(); 
		}
		
		if(this.options.search)
		{
			searchDiv = new Element('div', {'id' : this.table.id + '-search', 'class':'prototools-search'});
			if(this.options.search == 'top') {
				this.table.insert({ before :  searchDiv});
				searchDiv.setStyle('border-bottom : none;');			
			}
			else {
				this.table.insert({ after :  searchDiv});
				searchDiv.setStyle('border-top : none;');			
			}
			this.createSearch();
		}
		
		if(this.options.paginate)
		{
			pagerDiv = new Element('div', {'id' : this.table.id + '-pager', 'class':'prototools-pager'});
			if(this.options.paginate == 'top') {
				this.table.insert({ before :  pagerDiv});
				pagerDiv.setStyle('border-bottom : none;');			
			}
			else {
				this.table.insert({ after :  pagerDiv});
				pagerDiv.setStyle('border-top : none;');			
			}
			this.createPager();
		}
	},
	
	// createRows -- this is really the heart of the script. createRows takes the data  in this.cache passes it through the filter tool, then passes it through the search tool and 
	// finally paginates the results displaying (creating rows) only the current page. if no records result then a message is displayed to the user. this always uses the cache 
	// and never this.data directly
	createRows : function(){
		var line = 1;
		var display, enddisplay, startdisplay, dataView, dat, col, searchStr,row, s;
		
		// header information
		this.table.insert({ top: this.createFirstRow() });	
		
		// data -> {filter} -> dataView -> {paginate} -> display
		dataView = this.cache;
		
		// if filtering is turned off or not currently being used then skip
		if(this.options.filter && !this.isCached && this.tools.filterData !== '') {
			col = this.tools.filterCol;
			dat = this.tools.filterData.toUpperCase();
			dataView = [];

			dataView = this.cache.inject([], function(array, rec, index) {
				if(rec[col].toString().toUpperCase().include(dat))
				{
					array.push(rec);
				}
				
				return array;
			});
		}
		
		if(this.options.search && !this.isCached && this.tools.searchData !== '') {
			dat = this.tools.searchData.toUpperCase();
			
			dataView = dataView.inject([], function(array, value, index) {
				searchStr = Object.values(value).inject('', function(acc, n) {
					return acc + " " + n;
				});
				
				if(searchStr.toUpperCase().include(dat)) {
					array.push(value);
				}
				
				return array;
			});
		}
		display = dataView;
		
		if(this.options.paginate) {
			this.tools.pages = Math.ceil(dataView.size() / this.options.pageCount);
			if(this.tools.page > this.tools.pages) { this.tools.page = this.tools.pages; }
			if(this.tools.page < 1) { this.tools.page = 1; }
			if(this.tools.pages === 0) { this.tools.page = 0; }
			
			$(this.table.id + '-page-current').update(this.tools.page);	// update current page on tool
			$(this.table.id + '-page-total').update(this.tools.pages);	// update total pages on tool
			
			// Instead of displaying all just display a "paginate window" to the user.
			startdisplay = this.options.pageCount * (this.tools.page - 1);
			enddisplay = this.options.pageCount * this.tools.page;
			display = dataView.slice(startdisplay, enddisplay);
		}
		
		display.each(function(i,index){
			this.table.insert({ bottom: this.createRow(i,index) });
			line = (line == 1) ?  2 : 1;
		}.bind(this));
		
		// if there are no results
		if(display.size() === 0) {
			s = this.tableColumnsName.size();
			row = '<tr class="data line0" id="'+this.table.id+'-0">\n';
			row += '\t<td class="'+this.table.id+'-column" colspan="' + s + '">'+this.msgs.emptyResults+'</td>\n';
			row += '\n</tr>';
			this.table.insert({ bottom: row });
		}
		
		if (this.orderField){ $( this.table.id+'-'+this.orderField).addClassName(this.order); }
		
		// the new dataView is set as the cache
		if(!this.isCached) {
			this.isCached = true;
			this.cache = dataView;
		}
	}
};