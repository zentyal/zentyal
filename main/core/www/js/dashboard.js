// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

Zentyal.namespace('Dashboard');
Zentyal.namespace('Dashboard.ConfigureWidgets');

Zentyal.Dashboard.updateAjaxValue = function(url, containerId) {
    var escapedId = Zentyal.escapeJQSelector(containerId);
    jQuery.ajax({
         url: url,
         datatype: 'json',
         success: function (response) {
            var container = jQuery('#' + escapedId);
            container.removeClass().addClass('summary_value', 'summary_' + response.responseJSON.type);
            container.html(response.responseJSON.value);
         }
    });
};

// XXX migrate blind effect
Zentyal.Dashboard.toggleClicked = function(element) {
    var elementId = Zentyal.escapeJQSelector(element);
    var contentSelector = '#' + elementId + '_content';
    var toggler = jQuery('#' + elementId + '_toggler');
    if(toggler.hasClass('minBox')) {
//        Effect.BlindUp(contentname, { duration: 0.5 });
        jQuery(contentSelector).hide();//('blind', { direction: 'vertical' }, 500);
        toggler.removeClass('minBox').addClass('maxBox');
    } else {
//        Effect.BlindDown(contentname, { duration: 0.5 });
        jQuery(contentSelector).show(); //('blind', { direction: 'vertical' }, 500);
        toggler.removeClass('maxBox').addClass('minBox');
    }
    jQuery.ajax({
         url: "/Dashboard/Toggle",
         type: 'post',
         data:  { element: element }
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
    str = "<div class='widgetBox' style='opacity: " + opacity + ";' id='widget_" + m + ":" + w["name"] + top_id + "'>" +
        "<div class='widgetTopBar'>" +
        "<div class='widgetTopBackground'></div>" +
        "<div style='cursor: " + cursor + ";' class='widgetHandle'></div>" +
        "<div class='widgetName'>" + w["title"] + "</div>" +
        "<div style='clear: both;'></div>" +
        "</div>" +
        "</div>";
    return str;
};

// Zentyal.Dashboard.ConfigureWidgets namespace
Zentyal.Dashboard.ConfigureWidgets.cur_wid_start = 0;
Zentyal.Dashboard.ConfigureWidgets.modules = [];

Zentyal.Dashboard.ConfigureWidgets.htmlFromWidgetList = function (module, widgets, start, end) {
   var i;
   var html = '';
   for (i = start; i < end; ++i) {
     var id = widgets[i]['id'];
     html += '<div class="widgetBarBox" id="' + id + '_placeholder">';
     html += Zentyal.Dashboard.widget(module,widgets[i],!widgets[i]['present']);
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
        prev = prev + '<a href="#" onclick="Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(\'' + module + '\', ' + new_start + '); return false;">'; // call
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
    next += '<a href="#" onclick="Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(\'' + module + '\', ' + new_start + '); return false;">';
    next += '<img src="/data/images/right.gif"/>';
    next += '</a>';
    next += '</div>';
    return next;
};

Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsDropable = function(module, widgets, start, end) {
    var j;
    for (j = start; j < end; ++j) {
        if(!widgets[j]['present']) {
            var wid = widgets[j]['id'];
            var drag = new Draggable(wid, {
                handle: 'widgetHandle',
                onDrag: function(d,e) {
                    if(e.clientY > 100) {
                        if(!this.loaded) {
                            new Ajax.Updater(d.element.id,
                                    '/Dashboard/Widget?module=' +
                                    d.module + '&widget=' + d.widget, {
                                method: 'get',
                                onComplete: function() {
                                    var elements = $(d.element.id).getElementsByClassName('closeBox');
                                    Effect.toggle(elements[0],'appear');
                                }
                            });
                            this.loaded = true;
                        }
                    }
                },
                onEnd: function(d) {
                    var left_offset = parseInt(d.element.getStyle('left'), 10);
                    var top_offset = parseInt(d.element.getStyle('top'), 10);
                    var dur = Math.sqrt(Math.abs(top_offset^2)+Math.abs(left_offset^2))*0.02;
                    new Effect.Move(d.element.id, {
                        x: -left_offset,
                        y: -top_offset,
                        duration: dur,
                        afterFinish: function() {
                            Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets(d.module, Zentyal.Dashboard.ConfigureWidgets.cur_wid_start);
                        }
                    });
                }
            });
            drag.parent = drag.element.parentNode;
            drag.module = module;
            drag.widget = widgets[j]['name'];
            drag.element.onChange = function() {};
            Sortable.sortables[drag.element.id + '_placeholder'] = drag.element;
        }
    }
};

Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsSortable = function (widget_id_list) {
     jQuery.each(widget_id_list, function (index, id) {
        if(id.indexOf('dashboard') === 0) {
            Sortable.create(id, {
                tag: 'div',
                handle: 'widgetHandle',
                dropOnEmpty: true,
                constraint: false,
                scroll: window,
                containment: widget_id_list,
                onUpdate: function(dashboard) {
                    var id = dashboard.id;
                    new Ajax.Request('/Dashboard/Update', {
                        method: 'post',
                        parameters: { dashboard: id, widgets: Sortable.sequence(id).join(',') }
                    });
//                    jQuery.ajax({
//                       url: '/Dashboard/Update',
//                       type: 'post',
//                       data: { dashboard: id, widgets: Sortable.sequence(id).join(',') }
//                    });
                }
            });
        }
    });
};

Zentyal.Dashboard.ConfigureWidgets.showModuleWidgets = function(module, start) {
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

    var widgets = mod['widgets'];
    var max_wids = 4;
    var end = start + max_wids;
    if(end > widgets.length) {
        end = widgets.length;
    }

    var widget_id_list = new Array();
    var j;
    var k = 0;
    for (j = start; j < end; ++j) {
        var id = 'widget_' + module + ':' + widgets[j]['name'];
        widgets[j]['id'] = id;
        // recalculate present because it can have changed
        widgets[j]['present'] =  jQuery('.dashboard #' + id).length > 0;
        widget_id_list[k] = id + '_placeholder';
        k += 1;
    }
    widget_id_list[k] = 'dashboard1';
    widget_id_list[k+1] = 'dashboard2';

    var html = Zentyal.Dashboard.ConfigureWidgets.htmlForPrevModuleWidgets(module, start);
    html += Zentyal.Dashboard.ConfigureWidgets.htmlFromWidgetList(module, widgets, start, end)
    html += Zentyal.Dashboard.ConfigureWidgets.htmlForNextModuleWidgets(module, start, max_wids, widgets.length);
    jQuery('#widget_list').html(html);

    Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsDropable(module, widgets, start, end)
    Zentyal.Dashboard.ConfigureWidgets.createModuleWidgetsSortable(widget_id_list);
};


