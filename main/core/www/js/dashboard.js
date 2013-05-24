// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();
Zentyal.namespace('Dashboard');
Zentyal.namespace('Dashboard.ConfigureWidgets');

Zentyal.Dashboard.createSortableDashboard = function() {
     jQuery('.dashboard').sortable({
                                  elements: '.widgetBox',
                                  dropOnEmpty: true,
                                  connectWith: '.dashboard',
                                  delay: 100,
                                  update: function(event, ui) {
                                      var dashboard = jQuery(this);
                                      Zentyal.Dashboard.dashboardSortableUpdate(dashboard);
                                  }
                               });
};

Zentyal.Dashboard.updateAjaxValue = function(url, containerId) {
    var escapedId = Zentyal.escapeSelector(containerId);
    jQuery.ajax({
         url: url,
         datatype: 'json',
         success: function (response) {
            var container = jQuery('#' + escapedId);
            container.removeClass().addClass('summary_value', 'summary_' + response.type);
            container.html(response.value);
         }
    });
};

Zentyal.Dashboard.toggleClicked = function(element) {
    var elementId = Zentyal.escapeSelector(element);
    var contentSelector = '#' + elementId + '_content';
    var toggler = jQuery('#' + elementId + '_toggler');
    // XXX blind effect has problems with the graphs will see if migration to flotr solves it
    if(toggler.hasClass('minBox')) {
        jQuery(contentSelector).hide('blind');
        toggler.removeClass('minBox').addClass('maxBox');
    } else {
        jQuery(contentSelector).show('blind');
        toggler.removeClass('maxBox').addClass('minBox');
    }
    jQuery.ajax({
         url: "/Dashboard/Toggle",
         type: 'post',
         data:  { element: element }
    });
};

Zentyal.Dashboard.closeWidget = function(wid) {
    var selector = '#widget_' + Zentyal.escapeSelector(wid);
    var widget = jQuery(selector);
    widget.fadeOut(500, function() {
        var dashboard = widget.closest('.dashboard');
        widget.remove();

        var placeholdeSel = selector + '_placeholder';
        if(jQuery(placeholdeSel).length > 0) {
            var parts = wid.split(':');
            Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(parts[0], Zentyal.Dashboard.ConfigureWidgets.cur_wid_start);
         }
        Zentyal.Dashboard.dashboardSortableUpdate(dashboard);
    });
};

Zentyal.Dashboard.dashboardSortableUpdate = function (dashboard) {
    var dashboardId = dashboard.attr('id');
    var widgets = dashboard.find('.widgetBox').map( function () {
        if (this.id === '') {
            return null;
        }
        return this.id.split('_')[1];
    }).get().join(',');

    jQuery.ajax({
        url: '/Dashboard/Update',
        type: 'post',
        data: { dashboard: dashboardId, widgets: widgets }
    });
};

Zentyal.Dashboard.widget = function(m,w,full) {
    var opacity,
     top_id,
     cursor,
     str;
    if(full) {
        opacity = 1;
        top_id = '';
        cursor = 'move';
    } else {
        opacity = 0.5;
        top_id = '_bar';
        cursor = 'default';
    }
    str = "<div class='widgetBox' style='opacity: " + opacity + ";' id='widget_" + m + ":" + w.name + top_id + "'>" +
        "<div class='widgetTopBar'>" +
        "<div class='widgetTopBackground'></div>" +
        "<div style='cursor: " + cursor + ";' class='widgetHandle'></div>" +
        "<div class='widgetName'>" + w.title + "</div>" +
        "<div style='clear: both;'></div>" +
        "</div>" +
        "</div>";
    return str;
};

Zentyal.Dashboard.parseWidgetId = function (wid) {
    var parts = wid.split('_')[1].split(':');
    return {
        module: parts[0],
        widget: parts[1]
    };
};

Zentyal.Dashboard.toggleClose = function () {
    jQuery('.closeBox').toggle(10);
};

Zentyal.Dashboard.closeNotification = function (msg) {
    jQuery('#notification_container').hide();
    jQuery.ajax({
                 url: '/SysInfo/CloseNotification',
                 data: {  message: msg  }
                });
};

Zentyal.Dashboard.equalsObject = function(a, b)  {
    var p;
    for (p in a)
    {
        if (!(p in b)) {
            return false;
        }

        var aEl = a[p];
        var bEl = b[p];
        var typeA = typeof(aEl);
        if (typeA !== typeof(bEl)) {
            return false;
        }
        if (aEl === null) {
            typeA = 'null';
        }
        switch(typeA)
        {
            case 'object':
                if (!aEl.equals(bEl)) { return false; }
                break;
            case 'function':
                if ((p !== 'equals') && (aEl.toString() !== bEl.toString())) { return false; }
                break;
            default:
                if (aEl !== bEl) { return false; }
                break;
        }
    }

    for (p in b)
    {
        if (!(p in a)) {
            return false;
        }
    }

    return true;
};

Zentyal.Dashboard.graphInfo = [];
Zentyal.Dashboard.updateGraph = function(element,value) {
    var id = element.attr('id');
    var g = Zentyal.Dashboard.graphInfo[id];
    for(var i = 0; i < g.length-1; i++) {
        g[i] = [i, g[i+1][1]];
    }
    g[g.length-1] = [g.length-1, value];
    jQuery.plot(
        '#' + Zentyal.escapeSelector(id), [
        {
            data: g
        }],
        {
            xaxis: { noTicks: 0 },
            yaxis: { noTicks: 2, tickFormatter: getBytes }
        }
    );
};

Zentyal.Dashboard.updateValue = function(element, item) {
    if (item.value_type === 'ajax') {
        jQuery.ajax({
                         url: item.ajax_url,
                         async: false,
                         dataType: 'json',
                         success: function(response) {
                            item.value = response.value;
                            element.removeClass().addClass('summary_value');
                            element.addClass('summary_' + response.type);
                         }
                   });
    }

    if (element.html() != item.value) {
        element.html(item.value);
        element.effect('highlight');
    }
};

Zentyal.Dashboard.statusInfo = [];

Zentyal.Dashboard.updateStatus = function (element, item, itemname) {
    var changed = 0;
    if (Zentyal.Dashboard.statusInfo[itemname]) {
       if (Zentyal.Dashboard.equalsObject(item,Zentyal.Dashboard.statusInfo[itemname])) {
           return;
       }
       changed = 1;
    }

    Zentyal.Dashboard.statusInfo[itemname] = item;
    var status;
    var button = Zentyal.Dashboard.statusStrings['restart_button'];
    var name = 'restart';
    if (item.enabled && item.running) {
        status = 'running';
    } else if (item.enabled && !item.running) {
        status = 'stopped';
        button = Zentyal.Dashboard.statusStrings['start_button'];
        name = 'start';
    } else if (!item.enabled && item.running) {
        status = 'unmanaged';
    } else {
        status = 'disabled';
    }
    var text;
    var tooltip;
    if (item.statusStr) {
        text = item.statusStr;
        tooltip = '';
    } else {
        text = Zentyal.Dashboard.statusStrings[status]['text'];
        tooltip = Zentyal.Dashboard.statusStrings[status]['tip'];
    }
    var new_text = "<span title='" + tooltip;
    new_text     += "' class='sleft'>" + text;
    new_text     += '</span>';
    if (item.enabled && !item.nobutton) {
        var restart_form = "<form action='/SysInfo/RestartService'>" +
                           "<input type='hidden' name='module' value='" + item.module + "'/>"  +
                           "<span class='sright'>" +
                           "<input class='inputButtonRestart' type='submit' name='" + name +
                            "' value='" + button + "'/> "+
                           "</span>" +
                           "</form>";
        new_text += restart_form;
    }
    element.html(new_text);
    if (changed) {
       element.effect('highlight');
    }
};

Zentyal.Dashboard.updateGraphRow = function(item, itemname) {
    for(var g = 0; g < item.graphs.length; g++) {
        var graphname = itemname + '_' + g;
        var graph = jQuery('#' + Zentyal.escapeSelector(graphname));
        Zentyal.Dashboard.updateGraph(graph, item.graphs[g].value);
    }
};

Zentyal.Dashboard.updateList = function(item, itemname) {
    var listname = itemname + '_table';
    var nonename = itemname + '_none';
    var list = jQuery('#' + Zentyal.escapeSelector(listname));
    var none = jQuery('#' + Zentyal.escapeSelector(nonename));
    if(item.ids.length === 0) {
        list.hide();
        none.show();
    } else {
        list.show();
        none.hide();
    }

    var listDOM = list.get(0);
    var rids = [];
    var id, row;
    for (var r = 1; r < listDOM.rows.length; r++) {
        row = listDOM.rows[r];
        id = row.attributes['id'].value;
        if(item.ids.indexOf(id) == -1) {
            row.remove();
            r--;
        } else {
            rids[r] = id;
        }
    }
    for (var i = 0; i < item.ids.length; i++) {
        id= item.ids[i];
        if(rids.indexOf(id) == -1) {
            row = listDOM.insertRow(i+1);
            row.setAttribute('id',id);
            var content = item.rows[id];
            for (var c = 0; c < content.length; c++) {
                var cell = row.insertCell(c);
                cell.innerHTML = content[c];
            }
            jQuery(row).effect('highlight');
        }
    }
};


Zentyal.Dashboard.updateWidget = function(widget) {
    if(widget === null) {
        return;
    }

    var widgetSelector = '#' + Zentyal.escapeSelector( widget.module + ":" + widget.name + '_content');
    var widgetcontents = jQuery(widgetSelector);

   //fade out no longer existent sections
   var currentSections = {};
   if(widget.sections) {
        jQuery.each(widget.sections, function(index, newsect) {
               var id = widget.module + ":" + widget.name + '_' + newsect.name + '_section';
               currentSections[id] = {};
        });
   }
   widgetcontents.children().each( function(index, oldsect) {
        if(!(oldsect.id in currentSections)) {
            oldsect = jQuery(oldsect);
            oldsect.fadeOut(500, function() {
                oldsect.remove();
            });
        }
    });

    var prevsect = null;
    if (widget.sections) {
      for(var i = 0; i < widget.sections.length; i++) {
        var s = widget.sections[i];
        var sect = widget.module + ":" + widget.name + '_' + s.name;
        var sectname = sect + '_section';
        var cursect = jQuery('#' + Zentyal.escapeSelector(sectname));
        if(cursect.length === 0) {
            var newsection = document.createElement("div");
            newsection.id = sectname;
            if (prevsect === null) {
                 widgetcontents.prepend(newsection);
            } else {
                prevsect.after(newsection);
            }
            jQuery.ajax({
                url: '/Dashboard/Section',
                data: {
                    module: widget.module,
                    widget: widget.name,
                    section: s.name
               },
               dataType: 'html',
               success: function (response) {
                   jQuery(newsection).html(response).effect('highlight');
              }
            });
            prevsect = jQuery(newsection);
            continue;
        } else {
            prevsect = cursect;
            jQuery.each(s.items, function(item,i) {
                var itemname = sect + '_' + i;
                var element = jQuery('#' + Zentyal.escapeSelector(itemname));
                if(item.type == 'value') {
                    Zentyal.Dashboard.updateValue(element, item);
                } else if(item.type == 'status') {
                    Zentyal.Dashboard.updateStatus(element, item, itemname);
                } else if(item.type == 'graph') {
                    Zentyal.Dashboard.updateGraph(element, item.value);
                } else if(item.type == 'graphrow') {
                    Zentyal.Dashboard.updateGraphRow(item, itemname);
                } else if(item.type == 'list') {
                    Zentyal.Dashboard.updateList(item, itemname);
                }
            });
        }
    }
  }
};


Zentyal.Dashboard.updateWidgets = function() {
    jQuery('.widgetBox').each(function(index, widgetBox) {
        var id = widgetBox.id;
        //id can be empty when draggin things
        if (id === '') {
           return true;
        }
        var idParts = Zentyal.Dashboard.parseWidgetId(id);
        var url = '/Dashboard/WidgetJSON?module=' + idParts.module + '&widget=' + idParts.widget;
        jQuery.ajax({
                         url:   url,
                         type: 'get',
                         dataType: 'json',
                         success: function(data) {
                            Zentyal.Dashboard.updateWidget(data);
                         }
                    });
        return true;
    });
};



//*** Zentyal.Dashboard.ConfigureWidgets namespace ***\\
Zentyal.Dashboard.ConfigureWidgets.cur_wid_start = 0;
Zentyal.Dashboard.ConfigureWidgets.modules = [];

Zentyal.Dashboard.ConfigureWidgets.show = function (title) {

    jQuery('<div id="configure_widgets_dialog"></div>').dialog({
        title: title,
        width: 980,
        height: 120,
        position: 'top',
        resizable: false,
        create: function (event, ui) {
            Zentyal.TableHelper.setLoading('configure_widgets_dialog');
            jQuery(event.target).load('/Dashboard/ConfigureWidgets', function() {
                Zentyal.Dashboard.toggleClose();
                jQuery(this).css({overflow: 'visible'});
            });
        },
       beforeClose: function() {
           Zentyal.Dashboard.toggleClose();
       }
    });
};

Zentyal.Dashboard.ConfigureWidgets.htmlFromWidgetList = function (module, widgets, start, end) {
   var i;
   var html = '';
   for (i = start; i < end; ++i) {
     var id = widgets[i]['id'];
     html += '<div class="widgetBarBox" id="' + id + '_placeholder">';
     html += Zentyal.Dashboard.widget(module,widgets[i],!widgets[i].present);
     html += '</div>';
   }
   return html;
};

Zentyal.Dashboard.ConfigureWidgets.htmlForPrevModuleWidgets = function(module, start) {
    var prev = '';

    var new_start = start - 1;
    var opacity = 1;
    var link = true;
    if(new_start < 0) {
        opacity = 0.5;
        new_start = 0;
        link = false;
    }
    prev = '<div class="widArrow" style="opacity: ' + opacity + '">';
    if(link) {
        prev = prev + '<a href="#" onclick="Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(\'' + module + '\', ' + new_start + ', true); return false;">'; // call
    }
    prev = prev + '<img src="/data/images/left.gif"/>';
    if(link) {
        prev = prev + '</a>';
    }
    prev = prev + '</div>';
    return prev;
};


Zentyal.Dashboard.ConfigureWidgets.htmlForNextModuleWidgets = function(module, start, maxWidgets, widgetsLength ) {
    var next = '';
    var new_start, opacity;
    if(start + maxWidgets >= widgetsLength) {
        new_start = start;
        opacity = 0.5;
    }  else {
        new_start = start + 1;
        opacity = 1;
    }
    next = '<div class="widArrow" style="opacity: ' + opacity + '">';
    next += '<a href="#" onclick="Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(\'' + module + '\', ' + new_start + ', true); return false;">';
    next += '<img src="/data/images/right.gif"/>';
    next += '</a>';
    next += '</div>';
    return next;
};

Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsSortable = function(module) {
    jQuery('#widget_list').sortable({
        elements: '.widgetBarBox',
        dropOnEmpty: true,
        connectWith: '.dashboard',
        containment: 'body',
        delay: 100,
        scroll : false,
        opacity: 0.8,
        start: function(event, ui) {
            var id = ui.item.attr('id');
            var idParts = Zentyal.Dashboard.parseWidgetId(id);
            jQuery.ajax({
                url: '/Dashboard/Widget?module=' + idParts.module + '&widget=' + idParts.widget,
                type: 'get',
                dataType: 'html',
                success: function(response) {
                    var widget = ui.item;
                    widget.removeClass().addClass('widgetBox');
                    widget.attr('id', id.replace(/_placeholder$/, ''));
                    widget.width(jQuery('#dashboard1').width());
                    widget.html(response);
                    widget.find('.closeBox').toggle(500); // XXX first?
                }
            });
        },
        stop: function (event, ui) {
            var widget = ui.item;
            var inside = widget.closest('#widget_list').length > 0;
            if (inside) {
                widget.removeClass().addClass('widgetBarBox').html('');
                // put _placeholder id back in place
                widget.attr('id', widget.attr('id') + '_placeholder');
            }
            Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(module, Zentyal.Dashboard.ConfigureWidgets.cur_wid_start);
        }
    });

};

Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets = function(module, start, changeModule) {
    if (changeModule === undefined) {
        changeModule = false;
    }

    Zentyal.Dashboard.ConfigureWidgets.cur_wid_start = start;
    var mod = null;
    jQuery.each(Zentyal.Dashboard.ConfigureWidgets.modules, function(index, modObject) {
        if (modObject.name === module) {
            mod = modObject;
            return false;
        }
        return true;
    });
    if (mod === null) {
       return;
    }

    var widgets = mod.widgets;
    var max_wids = 4;
    var end = start + max_wids;
    if(end > widgets.length) {
        end = widgets.length;
    }

    for (var i = start; i < end; ++i) {
        var id = 'widget_' + module + ':' + widgets[i]['name'];
        widgets[i].id = id;
        // recalculate present because it can have changed
        widgets[i].present =  jQuery('.dashboard #' + Zentyal.escapeSelector(id)).length > 0;
    }

    var html = Zentyal.Dashboard.ConfigureWidgets.htmlForPrevModuleWidgets(module, start);
    html += Zentyal.Dashboard.ConfigureWidgets.htmlFromWidgetList(module, widgets, start, end);
    html += Zentyal.Dashboard.ConfigureWidgets.htmlForNextModuleWidgets(module, start, max_wids, widgets.length);
    jQuery('#widget_list').html(html);

    if (changeModule) {
        Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsSortable(module);
    }
};


