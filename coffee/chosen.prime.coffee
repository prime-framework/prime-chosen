###
Chosen source: generate output using 'cake build'
Copyright (c) 2011 by Harvest
###
root = this

class Chosen extends AbstractChosen

  setup: ->
    @is_multiple = @form_field.attribute('multiple') != null
    @current_value = @form_field.getValue()
    @is_rtl = @form_field.hasClass "chzn-rtl"

  finish_setup: ->
    @form_field.addClass "chzn-done"

  set_default_values: ->
    #hacky hacky, but the AbstractChosen expects there to be options on the form_field...maybe re-introduce prime_field?
    @form_field.options = @form_field.domElement.options
    
    super()
    
    # HTML Templates
    @single_temp = new Prime.Dom.Template('<a href="javascript:void(0)" class="chzn-single chzn-default"><span>#{default}</span><div><b></b></div></a><div class="chzn-drop" style="left:-9000px;"><div class="chzn-search"><input type="text" autocomplete="off" /></div><ul class="chzn-results"></ul></div>')
    @multi_temp = new Prime.Dom.Template('<ul class="chzn-choices"><li class="search-field"><input type="text" value="#{default}" class="default" autocomplete="off" style="width:25px;" /></li></ul><div class="chzn-drop" style="left:-9000px;"><ul class="chzn-results"></ul></div>')
    @choice_temp = new Prime.Dom.Template('<li class="search-choice" id="#{id}"><span>#{choice}</span><a href="javascript:void(0)" class="search-choice-close" rel="#{position}"></a></li>')
    @no_results_temp = new Prime.Dom.Template('<li class="no-results">' + @results_none_found + ' "<span>#{terms}</span>"</li>')

  set_up_html: ->
    @container_id = @form_field.id.replace(/[^\w]/g, '_') + "_chzn"
    
    @f_width = if @form_field.getStyle("width") then parseInt @form_field.getStyle("width"), 10 else @form_field.getComputedStyle()['width']
    
    container_props =
      'id': @container_id
      'class': "chzn-container#{ if @is_rtl then ' chzn-rtl' else '' }"
      'style': 'width: ' + (@f_width) + 'px' #use parens around @f_width so coffeescript doesn't think + ' px' is a function parameter
    
    base_template = Prime.Dom.newElement('<div/>', container_props)
    if @is_multiple then @multi_temp.appendTo(base_template, { "default": @default_text}) else @single_temp.appendTo(base_template, { "default": @default_text})

    base_template.insertAfter(@form_field)
    @form_field.hide();
    @container = Prime.Dom.queryByID(@container_id)
    @container.addClass( "chzn-container-" + (if @is_multiple then "multi" else "single") )
    @dropdown = Prime.Dom.queryFirst('div.chzn-drop', @container)
    
    dd_top = @container.getComputedStyle()['height']
    dd_width = (@f_width - get_side_border_padding(@dropdown))
    
    @dropdown.setStyles({"width": dd_width  + "px", "top": dd_top + "px"})

    @search_field = Prime.Dom.queryFirst('input', @container)
    @search_results = Prime.Dom.queryFirst('ul.chzn-results', @container)
    this.search_field_scale()

    #@search_no_results = @container.down('li.no-results')
    @search_no_results = Prime.Dom.queryFirst('li.no-results', @container)
    
    if @is_multiple
      #@search_choices = @container.down('ul.chzn-choices')
      #@search_container = @container.down('li.search-field')
      @search_choices = Prime.Dom.queryFirst('ul.chzn-choices', @container)
      @search_container = Prime.Dom.queryFirst('li.search-field', @container)
    else
      #@search_container = @container.down('div.chzn-search')
      #@selected_item = @container.down('.chzn-single')
      @search_container = Prime.Dom.queryFirst('div.chzn-search', @container)
      @selected_item = Prime.Dom.queryFirst('.chzn-single', @container)
      sf_width = dd_width - get_side_border_padding(@search_container) - get_side_border_padding(@search_field)
      @search_field.setStyles( {"width" : sf_width + "px"} )
    
    this.results_build()
    this.set_tab_index()
    @form_field.fireEvent("liszt:ready", {chosen: this})

  register_observers: ->
    @container.withEventListener "mousedown", (evt) => this.container_mousedown(evt)
    @container.withEventListener "mouseup", (evt) => this.container_mouseup(evt)
    @container.withEventListener "mouseenter", (evt) => this.mouse_enter(evt)
    @container.withEventListener "mouseleave", (evt) => this.mouse_leave(evt)
    
    @search_results.withEventListener "mouseup", (evt) => this.search_results_mouseup(evt)
    @search_results.withEventListener "mouseover", (evt) => this.search_results_mouseover(evt)
    @search_results.withEventListener "mouseout", (evt) => this.search_results_mouseout(evt)
    
    @form_field.withEventListener "liszt:updated", (evt) => this.results_update_field(evt)

    @search_field.withEventListener "blur", (evt) => this.input_blur(evt)
    @search_field.withEventListener "keyup", (evt) => this.keyup_checker(evt)
    @search_field.withEventListener "keydown", (evt) => this.keydown_checker(evt)

    if @is_multiple
      @search_choices.withEventListener "click", (evt) => this.choices_click(evt)
      @search_field.withEventListener "focus", (evt) => this.input_focus(evt)
    else
      @container.withEventListener "click", (evt) => evt.preventDefault() # gobble click of anchor

  prepare_event: (evt) ->
    if evt.target
      evt.target = new Prime.Dom.Element(evt.target)

  search_field_disabled: ->
    @is_disabled = @form_field.attribute 'disabled'
    if(@is_disabled)
      @container.addClass 'chzn-disabled'
      @search_field.setAttribute('disabled', true)
      @selected_item.removeEventListener "focus", @activate_proxy if !@is_multiple
      this.close_field()
    else
      @container.removeClass 'chzn-disabled'
      @search_field.setAttribute('disabled', false)
      @activate_proxy = @selected_item.addEventListener "focus", @activate_action if !@is_multiple

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
        else if not @is_multiple and evt and (prime_target is @selected_item || Prime.Dom.ancestor("a.chzn-single", prime_target) != null)
          this.results_toggle()

        this.activate_field()
      else
        @pending_destroy_click = false
  
  container_mouseup: (evt) ->
    this.results_reset(evt) if evt.target.nodeName is "ABBR" and not @is_disabled

  blur_test: (evt) ->
    this.close_field() if not @active_field and @container.hasClass("chzn-container-active")

  close_field: ->
    #document.stopObserving "click", @click_test_action
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
    if prime_target and Prime.Dom.ancestor('#' + @container_id, prime_target) != null
      @active_field = true
    else
      this.close_field()

  results_build: ->
    @parsing = true
    @results_data = root.SelectParser.select_to_array(@form_field.domElement)

    if @is_multiple and @choices > 0
      Prime.Dom.queryFirst("li.search-choice", @search_choices).removeFromDOM()
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
      '<li id="' + group.dom_id + '" class="group-result">' + group.label.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); + '</li>'
    else
      ""
  
  result_do_highlight: (el) ->
      this.result_clear_highlight()

      @result_highlight = el
      @result_highlight.addClass "highlighted"

      styles = @search_results.getComputedStyle()
      
      maxHeight = parseInt styles['maxHeight'], 10
      visible_top = styles['scrollTop']
      visible_bottom = maxHeight + visible_top

      high_top = @result_highlight.position()['top']
      high_bottom = high_top + @result_highlight.getComputedStyle()['height']

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
      @form_field.fireEvent("liszt:maxselected", {chosen: this})
      return false

    dd_top = if @is_multiple then @container.getComputedStyle()['height'] else (@container.getComputedStyle()['height'] - 1)
    @form_field.fireEvent("liszt:showing_dropdown", {chosen: this})
    @dropdown.setStyles {"top":  dd_top + "px", "left":0}
    @results_showing = true

    @search_field.fireEvent("focus")
    #@search_field.setValue @search_field.getValue

    #this.winnow_results()

  results_hide: ->
    @selected_item.removeClass('chzn-single-with-drop') unless @is_multiple
    this.result_clear_highlight()
    @form_field.fireEvent("liszt:hiding_dropdown", {chosen: this})
    @dropdown.setStyles({"left":"-9000px"})
    @results_showing = false


  set_tab_index: (el) ->
    if @form_field.attribute 'tabIndex'
      ti = @form_field.attribute 'tabIndex'
      @form_field.setAttribute 'tabIndex', -1

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
    target = if prime_target and prime_target.hasClass("active-result") then prime_target else Prime.Dom.ancestor(".active-result", prime_target)
    if prime_target
      @result_highlight = prime_target
      this.result_select(evt)

  search_results_mouseover: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    target = if prime_target.hasClass("active-result") then prime_target else Prime.Dom.ancestor(".active-result", prime_target)
    this.result_do_highlight( target ) if target

  search_results_mouseout: (evt) ->
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    this.result_clear_highlight() if prime_target and prime_target.hasClass('active-result') or Prime.Dom.ancestor(".active-result", prime_target)

  choices_click: (evt) ->
    evt.preventDefault()
    prime_target = if evt? then new Prime.Dom.Element(evt.target) else false
    if( @active_field and not(prime_target.hasClass('search-choice') or Prime.Dom.ancestor(".search-choice", prime_target)) and not @results_showing )
      this.results_show()

  choice_build: (item) ->
    if @is_multiple and @max_selected_options <= @choices
      @form_field.fireEvent("liszt:maxselected", {chosen: this})
      return false
    choice_id = @container_id + "_c_" + item.array_index
    @choices += 1
    # @search_container.insert
    #   before: @choice_temp.evaluate
    #     id:       choice_id
    #     choice:   item.html
    #     position: item.array_index
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
    Prime.Dom.ancestor('li', link).removeFromDOM()

  results_reset: ->
    #@form_field.options[0].selected = true
    Prime.Dom.query("option", @form_field)[0].setAttribute("selected", true);
    #@selected_item.down("span").update(@default_text)
    Prime.Dom.queryFirst("span", @selected_item).setHTML(@default_text);
    @selected_item.addClass("chzn-default") if not @is_multiple    
    this.show_search_field_default()
    this.results_reset_cleanup()
    #@form_field.simulate("change") if typeof Event.simulate is 'function'
    @form_field.fireEvent("change") if typeof Event.simulate is 'function'
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
        # @search_results.descendants(".result-selected").invoke "removeClassName", "result-selected"
        Prime.Dom.query(".result-selected", @search_results).each (index) -> this.removeClass("result-selected")
        @selected_item.removeClass("chzn-default")
        @result_single_selected = high
      
      high.addClass("result-selected")
        
      position = high.id.substr(high.id.lastIndexOf("_") + 1 )
      item = @results_data[position]
      item.selected = true

      #@form_field.options[item.options_index].selected = true
      Prime.Dom.query("option", @form_field)[item.options_index].setAttribute("selected", true)
      
      if @is_multiple
        this.choice_build item
      else
        #@selected_item.down("span").update(item.html)
        Prime.Dom.queryFirst("span", @selected_item).setHTML(item.html)
        this.single_deselect_control_build() if @allow_single_deselect

      this.results_hide() unless evt.metaKey and @is_multiple

      @search_field.setValue ""
      
      @form_field.fireEvent("change") if typeof Event.simulate is 'function' && (@is_multiple || @form_field.value != @current_value)
      @current_value = @form_field.getValue
      
      this.search_field_scale()

  result_activate: (el) ->
    el.addClass "active-result"

  result_deactivate: (el) ->
    el.removeClass "active-result"

  result_deselect: (pos) ->
    result_data = @results_data[pos]
    result_data.selected = false

    #@form_field.options[result_data.options_index].selected = false
    Prime.Dom.query("option", @form_field)[result_data.options_index].setAttribute("selected", false)
    #result = $(@container_id + "_o_" + pos)
    result = Prime.Dom.queryByID(@container_id + "_o_" + pos)
    result.removeClass("result-selected").addClass("active-result").show()

    this.result_clear_highlight()
    this.winnow_results()

    @form_field.fireEvent("change") if typeof Event.simulate is 'function'
    this.search_field_scale()
    
  single_deselect_control_build: ->
    #@selected_item.down("span").insert { after: "<abbr class=\"search-choice-close\"></abbr>" } if @allow_single_deselect and not @selected_item.down("abbr")
    #Prime.Dom.queryFirst("span", @selected_item).append(Prime.Dom.newElement("<abbr/>",{'class':'search-choice-close'})) if @allow_single_deselect and not Prime.Dom.queryFirst("abbr", @selected_item)
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
          Prime.Dom.query("option", @form_field)[option.options_index].hide()
        else if not (@is_multiple and option.selected)
          found = false
          
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
            #$(result_id).update text if $(result_id).innerHTML != text
            Prime.Dom.query("option", @form_field)[option.options_index].setHTML(text)
              
            this.result_activate Prime.Dom.queryByID(option.dom_id)

            Prime.Dom.query("optgroup", @form_field)[option.group_array_index].setStyle({display: 'list-item'}) if option.group_array_index?
          else
            this.result_clear_highlight() if option is @result_highlight
            this.result_deactivate Prime.Dom.query("option", @form_field)[option.options_index]

    if results < 1 and searchText.length
      this.no_results(searchText)
    else
      this.winnow_results_set_highlight()

  winnow_results_clear: ->
    @search_field.setValue ''
    #lis = @search_results.select("li")
    lis = Prime.Dom.query("li", @search_results)
    
    for li in lis
      if li.hasClass("group-result")
        li.show()
      else if not @is_multiple or not li.hasClass("result-selected")
        this.result_activate li

  winnow_results_set_highlight: ->
    if not @result_highlight

      if not @is_multiple
        #do_high = @search_results.down(".result-selected.active-result")
        do_high = Prime.Dom.queryFirst(".result-selected.active-result", @search_results)

      if not do_high?
        #do_high = @search_results.down(".active-result")
        do_high = Prime.Dom.queryFirst(".active-result", @search_results)

      this.result_do_highlight do_high if do_high?
  
  no_results: (terms) ->
    #@search_results.insert @no_results_temp.evaluate( terms: terms )
    @no_results_temp.appendTo(@search_results, terms)
    
  no_results_clear: ->
    nr = null
    #nr.remove() while nr = @search_results.down(".no-results")
    Prime.Dom.query(".no-results", @search_results).each () -> this.removeFromDOM()


  keydown_arrow: ->
    #actives = @search_results.select("li.active-result")
    actives = Prime.Dom.query("li.active-result", @search_results)
    if actives.length
      if not @result_highlight
        this.result_do_highlight actives[0]
      else if @results_showing
        #sibs = @result_highlight.nextSiblings()
        #nexts = sibs.intersect(actives)
        #this.result_do_highlight nexts.first() if nexts.length
        idx = actives.indexOf @results_showing
        this.result_do_highlight actives[idx + 1] if idx < actives.length - 1
      this.results_show() if not @results_showing

  keyup_arrow: ->
    if not @results_showing and not @is_multiple
      this.results_show()
    else if @result_highlight
      #sibs = @result_highlight.previousSiblings()
      #actives = @search_results.select("li.active-result")
      #prevs = sibs.intersect(actives)
      actives = Prime.Dom.query("li.active-result", @search_results)
      idx = actives.indexOf @result_highlight
      
      if idx > 0
        this.result_do_highlight actives[0]
      else
        this.results_hide() if @choices > 0
        this.result_clear_highlight()

  keydown_backstroke: ->
    if @pending_backstroke
      this.choice_destroy Prime.Dom.queryFirst("a", @pending_backstroke)
      this.clear_backstroke()
    else
      siblings = Prime.Dom.query("li.search-choice", @search_container)
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
        @backstroke_length = this.search_field.value.length
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
      #not as fancy as other implementations but we don't have great measuring facilities in Prime-JS
      @search_field.setStyles({'width': (@f_width - 10) + 'px'})

      dd_top = @container.getComputedStyle()['height']
      @dropdown.setStyles({"top":  dd_top + "px"})

root.Chosen = Chosen

get_side_border_padding = (elmt) ->
  layout = elmt.getComputedStyle();
  side_border_padding = parse_dimension(layout["borderLeftWidth"]) + parse_dimension(layout["borderRightWidth"]) + parse_dimension(layout["paddingLeft"]) + parse_dimension(layout["paddingRight"])
  
parse_dimension = (dim) ->
  parseInt dim.substring(0, dim.indexOf("px")), 10

root.get_side_border_padding = get_side_border_padding
root.parse_dimension = parse_dimension
