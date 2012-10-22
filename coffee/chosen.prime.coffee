###
Chosen source: generate output using 'cake build'
Copyright (c) 2012 by Inversoft
###
root = this

class Chosen extends AbstractChosen

  @CHOSEN_ANONYMOUS_ID: 1

  constructor: (@form_field, @options={}) ->
    @prime_field = if @form_field instanceof Prime.Dom.Element then @form_field else new Prime.Dom.Element(@form_field)
    id = @prime_field.getID()
    @prime_field.setID("chosen_" + Chosen.CHOSEN_ANONYMOUS_ID++) if (id? or id is "")
    @prime_field.chosen = this;
    @form_field = @prime_field.domElement
    super(@form_field, @options)

  setup: ->
    @current_value = @prime_field.getValue()
    @is_rtl = @prime_field.hasClass "chzn-rtl"
    @allow_custom_value = @prime_field.hasClass "chzn-custom-value" || @options.allow_custom_value

  finish_setup: ->
    @prime_field.addClass "chzn-done"

  set_default_values: ->
    super()
    
    # HTML Templates
    @single_temp = new Prime.Dom.Template('<a href="javascript:void(0)" class="chzn-single chzn-default"><span>#{default}</span><div><b></b></div></a><div class="chzn-drop" style="left:-9000px;"><div class="chzn-search"><input type="text" autocomplete="off" /></div><ul class="chzn-results"></ul></div>')
    @multi_temp = new Prime.Dom.Template('<ul class="chzn-choices"><li class="search-field"><input type="text" value="#{default}" class="default" autocomplete="off" style="width:25px;" /></li></ul><div class="chzn-drop" style="left:-9000px;"><ul class="chzn-results"></ul></div>')
    @choice_temp = new Prime.Dom.Template('<li class="search-choice" id="#{id}"><span>#{choice}</span><a href="javascript:void(0)" class="search-choice-close" rel="#{position}"></a></li>')
    @no_results_temp = new Prime.Dom.Template('<li class="no-results">#{message} "<span>#{terms}</span>"</li>')
    @group_temp = new Prime.Dom.Template('<li id="#{id}" class="group-result" style="display: list-item">#{label}</li>')
    @custom_choice_temp = new Prime.Dom.Template('<option value="#{value}" selected="selected">#{value}</option>')

  set_up_html: ->
    @container_id = @prime_field.getID().replace(/[^\w]/g, '_') + "_chzn"
    
    @f_width = if @prime_field.getStyle("width") then parseInt @prime_field.getStyle("width"), 10 else @prime_field.getComputedStyle()['width']
    
    container_props =
      'id': @container_id
      'class': "chzn-container#{ if @is_rtl then ' chzn-rtl' else '' }"
      'style': 'width: ' + (@f_width) + 'px' #use parens around @f_width so coffeescript doesn't think + ' px' is a function parameter
    
    base_template = Prime.Dom.newElement('<div/>', container_props)
    if @is_multiple then @multi_temp.appendTo(base_template, { "default": @default_text}) else @single_temp.appendTo(base_template, { "default": @default_text})

    base_template.insertAfter(@prime_field)
    @prime_field.hide();
    @container = Prime.Dom.queryByID(@container_id)
    @container.addClass( "chzn-container-" + (if @is_multiple then "multi" else "single") )
    @dropdown = Prime.Dom.queryFirst('div.chzn-drop', @container)
    
    dd_top = @container.getComputedStyle()['height']
    dd_width = (@f_width - get_side_border_padding(@dropdown))
    
    @dropdown.setStyles({"width": dd_width  + "px", "top": dd_top + "px"})

    @search_field = Prime.Dom.queryFirst('input', @container)
    @search_results = Prime.Dom.queryFirst('ul.chzn-results', @container)
    this.search_field_scale()

    @search_no_results = Prime.Dom.queryFirst('li.no-results', @container)
    
    if @is_multiple
      @search_choices = Prime.Dom.queryFirst('ul.chzn-choices', @container)
      @search_container = Prime.Dom.queryFirst('li.search-field', @container)
    else
      @search_container = Prime.Dom.queryFirst('div.chzn-search', @container)
      @selected_item = Prime.Dom.queryFirst('.chzn-single', @container)
      sf_width = dd_width - get_side_border_padding(@search_container) - get_side_border_padding(@search_field)
      @search_field.setStyles( {"width" : sf_width + "px"} )
    
    this.results_build()
    this.set_tab_index()
    @prime_field.fireEvent("liszt:ready", {chosen: this})

  register_observers: ->
    @container.addEventListener "mousedown", (evt) => this.container_mousedown(evt)
    @container.addEventListener "mouseup", (evt) => this.container_mouseup(evt)
    @container.addEventListener "mouseenter", (evt) => this.mouse_enter(evt)
    @container.addEventListener "mouseleave", (evt) => this.mouse_leave(evt)
    
    @search_results.addEventListener "mouseup", (evt) => this.search_results_mouseup(evt)
    @search_results.addEventListener "mouseover", (evt) => this.search_results_mouseover(evt)
    @search_results.addEventListener "mouseout", (evt) => this.search_results_mouseout(evt)
    
    @prime_field.addEventListener "liszt:updated", (evt) => this.results_update_field(evt)

    @search_field.addEventListener "blur", (evt) => this.input_blur(evt)
    @search_field.addEventListener "keyup", (evt) => this.keyup_checker(evt)
    @search_field.addEventListener "keydown", (evt) => this.keydown_checker(evt)

    if @is_multiple
      @search_choices.addEventListener "click", (evt) => this.choices_click(evt)
      @search_field.addEventListener "focus", (evt) => this.input_focus(evt)
    else
      @container.addEventListener "click", (evt) => evt.preventDefault() # gobble click of anchor

  prepare_event: (evt) ->
    if evt.target
      evt.target = new Prime.Dom.Element(evt.target)

  search_field_disabled: ->
    @is_disabled = @prime_field.getAttribute 'disabled'
    if(@is_disabled)
      @container.addClass 'chzn-disabled'
      #setAttribute didn't work for this
      @search_field.domElement.disabled = true
      @selected_item.removeEventListener "focus" if !@is_multiple
      this.close_field()
    else
      @container.removeClass 'chzn-disabled'
      #setAttribute didn't work for this
      @search_field.domElement.disabled = false
      @selected_item.addEventListener "focus", @activate_action if !@is_multiple

  container_mousedown: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    if !@is_disabled
      target_closelink =  if prime_target then prime_target.hasClass "search-choice-close" else false
      if evt and evt.type is "mousedown" and not @results_showing
        evt.preventDefault
        evt.stopPropogation
      if not @pending_destroy_click and not target_closelink
        if not @active_field
          @search_field.setValue('') if @is_multiple
          @click_test_proxy = Prime.Dom.Document.addEventListener "click", @click_test_action
          this.results_show()
        else if not @is_multiple and evt and (prime_target is @selected_item || Prime.Dom.queryUp("a.chzn-single", prime_target) != null)
          this.results_toggle()

        this.activate_field()
      else
        @pending_destroy_click = false
  
  container_mouseup: (evt) ->
    this.results_reset(evt) if evt.target.nodeName is "ABBR" and not @is_disabled

  blur_test: (evt) ->
    this.close_field() if not @active_field and @container.hasClass("chzn-container-active")

  close_field: ->
    Prime.Dom.Document.removeEventListener "click", @click_test_proxy
    
    if not @is_multiple
      @selected_item.setAttribute 'tabIndex', @search_field.attribute('tabIndex')
      @search_field.setAttribute 'tabIndex', -1
    
    @active_field = false
    this.results_hide()

    @container.removeClass "chzn-container-active"
    this.winnow_results_clear()
    this.clear_backstroke()

    this.show_search_field_default()
    this.search_field_scale()

  activate_field: ->
    if not @is_multiple and not @active_field
      @search_field.setAttribute 'tabIndex', @selected_item.attribute('tabIndex')
      @selected_item.setAttribute 'tabIndex', -1

    @container.addClass "chzn-container-active"
    @active_field = true

    @search_field.setValue @search_field.getValue()
    @search_field.domElement.focus()


  test_active_click: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    if prime_target and Prime.Dom.queryUp('#' + @container_id, prime_target) != null
      @active_field = true
    else
      this.close_field()

  results_build: ->
    @parsing = true
    @results_data = root.SelectParser.select_to_array(@form_field)

    if @is_multiple and @choices > 0
      Prime.Dom.query("li.search-choice", @search_choices).each () -> this.removeFromDOM()
      @choices = 0
    else if not @is_multiple
      @selected_item.addClass("chzn-default")
      Prime.Dom.queryFirst("span", @selected_item).setHTML(@default_text)
      if @results_data.length <= @disable_search_threshold
        @container.addClass "chzn-container-single-nosearch"
      else
        @container.removeClass "chzn-container-single-nosearch"

    content = ''
    for data in @results_data
      if data.group
        content += this.result_add_group data
      else if !data.empty
        content += this.result_add_option data
        if data.selected and @is_multiple
          this.choice_build data
        else if data.selected and not @is_multiple
          @selected_item.removeClass("chzn-default")
          Prime.Dom.queryFirst("span", @selected_item).setHTML( data.html )
          this.single_deselect_control_build() if @allow_single_deselect

    this.search_field_disabled()
    this.show_search_field_default()
    this.search_field_scale()
    
    @search_results.setHTML content
    @parsing = false


  result_add_group: (group) ->
    if not group.disabled
      group.dom_id = @container_id + "_g_" + group.array_index
      @group_temp.generate({'id': group.dom_id, 'label': group.label.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')})
    else
      ""
  
  result_do_highlight: (el) ->
    this.result_clear_highlight()

    @result_highlight = el
    @result_highlight.addClass "highlighted"

    styles = @search_results.getComputedStyle()
    
    maxHeight = parseInt styles['maxHeight'], 10
    visible_top = @search_results.domElement.scrollTop
    visible_bottom = maxHeight + visible_top
    
    high_top = calculate_position(@result_highlight)['top']
    high_bottom = high_top + parseInt(@result_highlight.getComputedStyle()['height'], 10)

    if high_bottom >= visible_bottom
      @search_results.domElement.scrollTop = if (high_bottom - maxHeight) > 0 then (high_bottom - maxHeight) else 0
    else if high_top < visible_top
      @search_results.domElement.scrollTop = high_top
    
  result_clear_highlight: ->
    @result_highlight.removeClass('highlighted') if @result_highlight
    @result_highlight = null

  results_show: ->
    if not @is_multiple
      @selected_item.addClass('chzn-single-with-drop')
      if @result_single_selected
        this.result_do_highlight( @result_single_selected )
    else if @max_selected_options <= @choices
      @prime_field.fireEvent("liszt:maxselected", {chosen: this})
      return false
    
    dd_top = if @is_multiple then parse_dimension(@container.getComputedStyle()['height']) else (parse_dimension(@container.getComputedStyle()['height']) - 1)
    @prime_field.fireEvent("liszt:showing_dropdown", {chosen: this})
    @dropdown.setStyles {"top":  dd_top + "px", "left":0}
    @results_showing = true

    @search_field.fireEvent "focus"
    #still not sure what this is serving
    @search_field.setValue @search_field.getValue()
    
    this.winnow_results()

  results_hide: ->
    @selected_item.removeClass('chzn-single-with-drop') unless @is_multiple
    this.result_clear_highlight()
    @prime_field.fireEvent("liszt:hiding_dropdown", {chosen: this})
    @dropdown.setStyles({"left":"-9000px"})
    @results_showing = false

  set_tab_index: (el) ->
    if @prime_field.getAttribute 'tabIndex'
      ti = @prime_field.getAttribute 'tabIndex'
      @prime_field.setAttribute 'tabIndex', -1

      if @is_multiple
        @search_field.setAttribute 'tabIndex', ti
      else
        @selected_item.setAttribute 'tabIndex', ti
        @search_field.setAttribute 'tabIndex', -1

  show_search_field_default: ->
    if @is_multiple and @choices < 1 and not @active_field
      @search_field.setValue @default_text
      @search_field.addClass "default"
    else
      @search_field.setValue ''
      @search_field.removeClass "default"

  search_results_mouseup: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    target = if prime_target and prime_target.hasClass("active-result") then prime_target else Prime.Dom.queryUp(".active-result", prime_target)
    if prime_target
      @result_highlight = prime_target
      this.result_select(evt)

  search_results_mouseover: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    target = if prime_target.hasClass("active-result") then prime_target else Prime.Dom.queryUp(".active-result", prime_target)
    this.result_do_highlight( target ) if target

  search_results_mouseout: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    this.result_clear_highlight() if prime_target and prime_target.hasClass('active-result') or Prime.Dom.queryUp(".active-result", prime_target)

  choices_click: (evt) ->
    evt.preventDefault()
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    if( @active_field and not(prime_target.hasClass('search-choice') or Prime.Dom.queryUp(".search-choice", prime_target)) and not @results_showing )
      this.results_show()

  choice_build: (item) ->
    if @is_multiple and @max_selected_options <= @choices
      @prime_field.fireEvent("liszt:maxselected", {chosen: this})
      return false
    choice_id = @container_id + "_c_" + item.array_index
    @choices += 1
    @choice_temp.insertBefore(@search_container, {id: choice_id, choice: item.html, position: item.array_index})
    link = Prime.Dom.queryFirst('li.#' + choice_id + ' a', @search_choices)
    link.addEventListener "click", (evt) => this.choice_destroy_link_click(evt)

  choice_destroy_link_click: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    evt.preventDefault()
    if not @is_disabled
      @pending_destroy_click = true
      this.choice_destroy prime_target

  choice_destroy: (link) ->
    @choices -= 1
    this.show_search_field_default()

    this.results_hide() if @is_multiple and @choices > 0 and @search_field.getValue().length < 1

    this.result_deselect link.getAttribute("rel")
    Prime.Dom.queryUp('li', link).removeFromDOM()

  results_reset: ->
    @form_field.options[0].selected = true
    Prime.Dom.queryFirst("span", @selected_item).setHTML(@default_text);
    @selected_item.addClass("chzn-default") if not @is_multiple    
    this.show_search_field_default()
    this.results_reset_cleanup()
    @prime_field.fireEvent("change") #if typeof Event.simulate is 'function'
    this.results_hide() if @active_field

  results_reset_cleanup: ->
    deselect_trigger = Prime.Dom.queryFirst("abbr", @selected_item)
    deselect_trigger.removeFromDOM() if(deselect_trigger)
  
  result_select: (evt) ->
    if @result_highlight
      high = @result_highlight
      this.result_clear_highlight()

      if @is_multiple
        this.result_deactivate high
      else
        Prime.Dom.query(".result-selected", @search_results).each (index) -> this.removeClass("result-selected")
        @selected_item.removeClass("chzn-default")
        @result_single_selected = high
      
      high.addClass("result-selected")
        
      position = high.getID().substr(high.getID().lastIndexOf("_") + 1 )
      item = @results_data[position]
      item.selected = true

      @form_field.options[item.options_index].selected = true
      
      if @is_multiple
        this.choice_build item
      else
        Prime.Dom.queryFirst("span", @selected_item).setHTML(item.html)
        this.single_deselect_control_build() if @allow_single_deselect

      this.results_hide() unless evt.metaKey and @is_multiple

      @search_field.setValue ""
      
      @prime_field.fireEvent("change") if typeof Event.simulate is 'function' && (@is_multiple || @prime_field.getValue() != @current_value)
      @current_value = @prime_field.getValue()
      
      this.search_field_scale()

    else if @allow_custom_value
      value = @search_field.getValue()
      group = @add_unique_custom_group()
      @custom_choice_temp.appendTo(group, {'value':value})

      group.appendTo(@prime_field) if group.parent() is null

      @results_hide() unless evt.metaKey
      @results_build()

  find_custom_group: ->
    found = group for group in Prime.Dom.query('optgroup', @prime_field) when group.getAttribute('label') is @custom_group_text

    found

  add_unique_custom_group: ->
    group = @find_custom_group()
    if not group
      group = Prime.Dom.newElement('<optgroup/>', {'label':@custom_group_text})
    
    group

  result_activate: (el) ->
    el.addClass "active-result"

  result_deactivate: (el) ->
    el.removeClass "active-result"

  result_deselect: (pos) ->
    result_data = @results_data[pos]
    result_data.selected = false

    @form_field.options[result_data.options_index].selected = false
    result = Prime.Dom.queryByID(@container_id + "_o_" + pos)
    result.removeClass("result-selected").addClass("active-result").show()

    this.result_clear_highlight()
    this.winnow_results()

    @prime_field.fireEvent("change") if typeof Event.simulate is 'function'
    this.search_field_scale()
    
  single_deselect_control_build: ->
    Prime.Dom.newElement("<abbr/>", {'class':'search-choice-close'}).appendTo(Prime.Dom.queryFirst("span", @selected_item)) if @allow_single_deselect and not Prime.Dom.queryFirst("abbr", @selected_item)
    
  winnow_results: ->
    this.no_results_clear()

    results = 0

    searchText = if @search_field.getValue() is @default_text then "" else @search_field.getValue().replace(/^\s+/, '').replace(/\s+$/, '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    regexAnchor = if @search_contains then "" else "^"
    regex = new RegExp(regexAnchor + searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')
    zregex = new RegExp(searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')
    
    for option in @results_data
      if not option.disabled and not option.empty
        if option.group
          Prime.Dom.queryByID(option.dom_id).hide()
        else if not (@is_multiple and option.selected)
          found = false
          result_id = option.dom_id
          el = Prime.Dom.queryByID(result_id)
          
          if regex.test option.html
            found = true
            results += 1
          else if option.html.indexOf(" ") >= 0 or option.html.indexOf("[") == 0
            #TODO: replace this substitution of /\[\]/ with a list of characters to skip.
            parts = option.html.replace(/\[|\]/g, "").split(" ")
            if parts.length
              for part in parts
                if regex.test part
                  found = true
                  results += 1

          if found
            if searchText.length
              startpos = option.html.search zregex
              text = option.html.substr(0, startpos + searchText.length) + '</em>' + option.html.substr(startpos + searchText.length)
              text = text.substr(0, startpos) + '<em>' + text.substr(startpos)
            else
              text = option.html
            
            el.setHTML(text)  
            this.result_activate el

            Prime.Dom.queryByID(@results_data[option.group_array_index].dom_id).setStyle('display', 'list-item') if option.group_array_index?
          else
            this.result_clear_highlight() if @result_highlight? and option.dom_id is @result_highlight.getID()
            this.result_deactivate el

    if results < 1 and searchText.length
      this.no_results(searchText)
    else    
      this.winnow_results_set_highlight()

  winnow_results_clear: ->
    @search_field.setValue ''
    lis = Prime.Dom.query("li", @search_results)
    
    for li in lis
      if li.hasClass("group-result")
        li.show()
      else if not @is_multiple or not li.hasClass("result-selected")
        this.result_activate li

  winnow_results_set_highlight: ->
    if not @result_highlight

      if not @is_multiple
        do_high = Prime.Dom.queryFirst(".result-selected.active-result", @search_results)

      if not do_high?
        do_high = Prime.Dom.queryFirst(".active-result", @search_results)

      this.result_do_highlight do_high if do_high?
  
  no_results: (terms) ->
    @no_results_temp.appendTo(@search_results, {'terms':terms, 'message': @results_none_found})
    
  no_results_clear: ->
    nr = null
    Prime.Dom.query(".no-results", @search_results).each () -> this.removeFromDOM()


  keydown_arrow: ->
    actives = Prime.Dom.query("li.active-result", @search_results)
    if actives.length
      if not @result_highlight
        this.result_do_highlight actives[0]
      else if @results_showing
        idx = actives.indexOf @result_highlight
        this.result_do_highlight actives[idx + 1] if idx < actives.length - 1
      this.results_show() if not @results_showing

  keyup_arrow: ->
    if not @results_showing and not @is_multiple
      this.results_show()
    else if @result_highlight
      actives = Prime.Dom.query("li.active-result", @search_results)
      idx = actives.indexOf @result_highlight
      
      if idx > 0
        this.result_do_highlight actives[idx - 1]
      else
        this.results_hide() if @choices > 0
        this.result_clear_highlight()

  keydown_backstroke: ->
    if @pending_backstroke
      this.choice_destroy Prime.Dom.queryFirst("a", @pending_backstroke)
      this.clear_backstroke()
    else
      siblings = Prime.Dom.query("li.search-choice", @search_container.parent())
      @pending_backstroke = siblings[siblings.length - 1]
      if @single_backstroke_delete
        @keydown_backstroke()
      else
        @pending_backstroke.addClass("search-choice-focus")

  clear_backstroke: ->
    @pending_backstroke.removeClass("search-choice-focus") if @pending_backstroke
    @pending_backstroke = null

  keydown_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    this.clear_backstroke() if stroke != 8 and this.pending_backstroke
    
    switch stroke
      when 8
        @backstroke_length = this.search_field.getValue().length
        break
      when 9
        this.result_select(evt) if this.results_showing and not @is_multiple
        @mouse_on_container = false
        break
      when 13
        evt.preventDefault()
        break
      when 38
        evt.preventDefault()
        this.keyup_arrow()
        break
      when 40
        this.keydown_arrow()
        break
        
  search_field_scale: ->
    if @is_multiple
      
      w = 0

      style_block = "position:absolute; left: -1000px; top: -1000px; visibility:hidden;"
      styles = ['font-size','font-style', 'font-weight', 'font-family','line-height', 'text-transform', 'letter-spacing']
      
      for style in styles
        style_block += style + ":" + @search_field.getStyle(style) + ";"
      
      div = Prime.Dom.newElement('<div/>', { 'style' : style_block }).setHTML(@search_field.getValue().replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'))
      div.appendTo(Prime.Dom.queryFirst('body'))
      
      comp = div.getComputedStyle()
      w = parse_dimension(comp['width']) + parse_dimension(comp['paddingLeft']) + parse_dimension(comp['paddingRight']) + parse_dimension(comp['borderLeftWidth']) + parse_dimension(comp['borderRightWidth']) + 25

      div.removeFromDOM()

      if( w > @f_width-10 )
        w = @f_width - 10
      
      #not as fancy as other implementations but we don't have much in the way of measuring facilities in Prime-JS
      #@search_field.setStyles({'width': (@f_width / 2) + 'px'})
      @search_field.setStyles({'width': w + 'px'})
      
      dd_top = @container.getComputedStyle()['height']
      @dropdown.setStyles({"top":  dd_top + "px"})

root.Chosen = Chosen

get_side_border_padding = (elmt) ->
  layout = elmt.getComputedStyle();
  side_border_padding = parse_dimension(layout["borderLeftWidth"]) + parse_dimension(layout["borderRightWidth"]) + parse_dimension(layout["paddingLeft"]) + parse_dimension(layout["paddingRight"])
  
calculate_position = (elmt) ->
  styles = elmt.getComputedStyle()
  # positionLeft = -(parse_dimension(styles['margin-left']))
  # positionTop = -(parse_dimension(styles['margin-top']))
  positionLeft = parseInt(elmt.domElement.offsetLeft, 10) - parseInt(styles['margin-left'], 10)
  positionTop = parseInt(elmt.domElement.offsetTop, 10) - parseInt(styles['margin-top'], 10)
  
  element = elmt.parent()
  while (element?)
    position = element.getComputedStyle()['position']
    if (element.type is 'body' or (position is 'relative' or position is 'absolute'))
      break;
    else
      positionLeft += parseInt(element.offsetLeft, 10)
      positionTop += parseInt(element.offsetTop, 10)
    element = element.parent()
  
  {'top': positionTop, 'left': positionLeft}
  
parse_dimension = (dim) ->
  if dim.indexOf("px") > 0 then parseInt(dim.substring(0, dim.indexOf("px")), 10) else parseInt(dim, 10)

root.get_side_border_padding = get_side_border_padding
root.calculate_position = calculate_position
root.parse_dimension = parse_dimension
