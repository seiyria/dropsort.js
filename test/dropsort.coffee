
class DropSort
  errorMsgs = 
    noElement: 'You have to specify an element to attach DropSort to'
    staticPos: 'You cannot use DropSort on an element with position: static set'
    invalidEl: 'Could not get the container for element'
    multiBind: 'You cannot bind to the same element multiple times'
    gridDimen: 'Your grid dimensions are invalid. They must be integers greater than 1'
    badHelper: 'You must specify a valid helper (it must be a function that returns a DOMElement, contain "clone" or "original")'
    noActions: 'You must specify an action (doDrag, doDrop, or doSort)'
    badHolder: 'You must give a valid DOMElement as a sort placeholder'
    isNotSort: 'This function only works on a sortable'
    noSorting: 'This function only works on a descendant of a sortable'
    poorIndex: 'You have to give a valid DropSort or an index to use when doing range selection'
    
  constructor: (@element, optionsSpecified = {}) ->

    throw new Error errorMsgs.noElement if not @element
    throw new Error errorMsgs.staticPos if DOMHelper.getStyle(@element, 'position') is 'static'
    
    #if we are a sortable, we need a copy of this
    @optionsCopy = _.clone optionsSpecified
    
    @options = _.defaults optionsSpecified,
    
      # bool or fn -> bool
      doDrag: true
    
      # bool or fn -> bool
      touchEnabled: 'ontouchstart' in window
      
      # string or function
      dragClass: 'ds-drag'

      # either a bool or a function -> bool
      dragAutoScroll: yes
      
      # either an int or a function -> int
      dragAutoScrollSpeed: 10
      
      # either an int or a function -> int
      dragScrollSensitivity: 0
      
      # either an int or a function -> int
      # does not currently work well with high numbers
      # it may work better if @element is manually repositioned after meeting minDragDistance
      minDragDistance: 0
      
      # initial delay to verify the mouse is still down before performing a drag
      # this helps to keep the drag from happening on accidental clicks
      dragDelay: 100
      
      # either original, clone, anchor, original anchor, clone anchor, function -> element
      dragHelper: "original anchor"
      
      # either a class name (no .), or a function -> class name
      dragHandleClassName: ""
      
      # either a bool or a function -> bool
      dragDisabled: no
      
      # either a number or a function -> number
      dragZIndex: 10
      
      # either a string or a function -> string
      dragAxis: "both"
      
      # either an array or function -> array
      dragGrid: [1, 1]
      
      # either an array, a selector, or a function -> array of nodes
      dragAnchorElements: []
      
      # either 'parent' or null or an element or a function (-> element)
      dragContainerType: null
      
      # object
      dragContainerBox:
        bottom: null
        right: null
        left: null
        top: null
        
      # called when the mouse is released after a drag action
      dragUpCallback: ->
        
      # called when the mouse first initiates a drag action
      dragStartCallback: ->
        
      # should this element be a drop target?
      doDrop: no
      
      # is this drop target active?
      dropDisabled: no
      
      # whether or not this can be dropped on. (element) -> bool
      canDropOn: (el) -> yes
      
      # a class or function -> class
      dropClass: 'ds-drop'
      
      # a class or ifunction -> class
      dropHoverClass: 'ds-drop-hover'
      
      # what types of elements (or, what specific element) should I accept?
      dropAccept: ''
      
      # what is the tolerance for being dropped in me? (supports fit, intersect*, pointer, touch)
      dropTolerance: 'touch'
      
      # what callback should happen when this is dropped?
      dropCallback: ->
        
      # what callback should happen while hovering over a drop target?
      dropHoverCallback: ->
      
      # should this element be a sortable container?
      doSort: no
      
      # the selector used to determine which children of a DropSort sortable
      # should be selected when doing sorts
      sortSelector: '*'
      
      # the rubber-banding function called after dropping an item that is 
      # part of a sortable
      sortRubberBand: (dropSort) ->
        dropSort.element.style.left = "auto"
        dropSort.element.style.top = "auto"
        dropSort.element.style.position = "relative"
        
      # the placeholder for the item being placed in a sortable.
      # required. by default, it is an empty element with the same tag
      # as the dragged item
      sortPlaceholder: =>
        document.createElement @element.tagName
        
      # the orientation of the sortable. if not vertical, horizontal assumed
      # can be a string (vertical, horizontal/other), or fn -> string
      sortOrientation: "vertical"
      
      # whether or not to allow re-sorting
      # this will not stop dragging.
      # either a bool or fn -> bool
      sortDisabled: no
      
      # what elements should this sortable accept?
      # either a selector, or a fn -> selector
      sortAcceptSelector: "*"
      
      # required to be non-empty for multi-select
      sortSelectedClass: "ds-selected"
      
      # this function generates a placeholder for dragging when you have a sortable
      # it only applies if you have a sortable
      sortDragPlaceholder: ->
      
      # this function is called when a sortable element is clicked
      # it is called if dragging is not happening
      # this allows for pre-sorting stuff, like item selection
      sortElementClick: (sortZone, elementClicked, event) ->

    # set up the initial variables and make sure they all work out
    do @doInitialVariableCalculations
    do @addBinding

    # figure out what we are
    # sortable takes priority over other configurations
    if _.result @options, 'doSort'
      do @setupSort
      
    else if _.result @options, 'doDrop'
      do @setupDrop
      
    else if _.result @options, 'doDrag'
      @mouse = new MouseAction @element
      do @setupDrag
      
    else
      throw new Error errorMsgs.noActions
    
  # Set up the options object if it is missing properties
  doInitialVariableCalculations: ->
    do @getContainerBoundingBox
    do @checkGrid
    do @setAxis
    do @setBaseZIndex
    do @checkIfHelperIsValid
    do @setupElement
    
  # set up the element that's being handled by DropSort
  # this includes adding a match() function and attaching a ref
  # to the containing DropSort instance
  setupElement: ->
    DOMHelper.setMatchesFunction @element
    @element._dropSort = @
    @element._dropSort._isSortSelected = no
    
  # Check if the helper is valid (ie, contains 'clone' or 'original' or is a DOMElement)
  checkIfHelperIsValid: ->
    helper = _.result @options, 'dragHelper'
    throw new Error errorMsgs.badHelper if (not _.isElement helper) and ((helper.indexOf 'clone') is -1) and ((helper.indexOf 'original') is -1)
    
  # Set DropSort.element's zIndex as a property on itself so we can modify it when dragging
  setBaseZIndex: ->
    @element._zIndex = DOMHelper.getStyle @element, 'z-index'

  # Set the default axis if one doesn't exist
  setAxis: ->
    axis = _.result @options, 'dragAxis'
    axis = 'both' if not axis
    @options.dragAxis = axis
    
  # Check if the grid passed into DropSort is valid and sets one if one doesn't exist
  checkGrid: ->
    grid = _.result @options, 'dragGrid'
    
    if not grid
      grid = [1, 1]
      
    if grid[0] < 1 or not MathHelper.divisibleBy grid[0] or grid[1] < 1 or not MathHelper.divisibleBy grid[1]
      throw new Error errorMsgs.gridDimen
      
    @options.dragGrid = grid
      
  # Get the bounding box for the current container element (if no container is set, it will use the parent of the element)
  getContainerBoundingBox: ->
    type = _.result @options, 'dragContainerType'
    return if type is null
    
    if type is 'parent'
      type = @element.parentNode
      
    if  _.isElement type
      @options.dragContainerBox = DOMHelper.getBoundingBoxFor type
      
    else
      throw new Error errorMsgs.invalidEl
      
  # Reposition the item that's currently being dragged
  repositionItem: (event, repositionMe = @element) ->
    
    grid = @options.dragGrid
    axis = @options.dragAxis

    offsetX = event.pageX
    offsetY = event.pageY
    mouseX = event.clientX
    mouseY = event.clientY

    if not (@dragStartPosition._xDiff or @dragStartPosition._yDiff)
      @dragStartPosition._xDiff = @dragStartPosition.left - offsetX
      @dragStartPosition._yDiff = @dragStartPosition.top - offsetY

    newX = offsetX + @dragStartPosition._xDiff
    newY = offsetY + @dragStartPosition._yDiff

    # autoscroll - currently broken
    # it kinda works, but it should scroll forever
    if (_.result @options, 'dragAutoScroll') and (autoScrollSpeed = _.result @options, 'dragAutoScrollSpeed')
      windowSize = DOMHelper.getWindowSize()
      sensitivity = _.result @options, 'dragScrollSensitivity'

      greaterY = -> mouseY >= windowSize.y - sensitivity
      greaterX = -> mouseX >= windowSize.x - sensitivity
      lesserY = -> mouseY <= 0 + sensitivity
      lesserX = -> mouseX <= 0 + sensitivity
    
      if greaterY()
        window.scrollIntervalGreaterY = setInterval ->
          window.scrollBy 0, autoScrollSpeed
        , 15
         
      else 
        clearInterval window.scrollIntervalGreaterY
    
      if greaterX()
        window.scrollIntervalGreaterX = setInterval ->
          window.scrollBy autoScrollSpeed, 0
        , 15
         
      else 
        clearInterval window.scrollIntervalGreaterX
    
      if lesserY()
        window.scrollIntervalLesserY = setInterval ->
          window.scrollBy 0, -autoScrollSpeed
        , 15
         
      else 
        clearInterval window.scrollIntervalLesserY
    
      if lesserX()
        window.scrollIntervalLesserX = setInterval ->
          window.scrollBy -autoScrollSpeed, 0
        ,15
         
      else 
        clearInterval window.scrollIntervalLesserX
     
    boundingBox = @options.dragContainerBox

    containment = 
      left: newX
      top: newY
      right: newX + repositionMe.offsetWidth
      bottom: newY + repositionMe.offsetHeight
      offsetWidth: repositionMe.offsetWidth
      offsetHeight: repositionMe.offsetHeight
      
    newElementBox = @isElementContainedChangePos containment, boundingBox
    
    elementBoundingBox = DOMHelper.getBoundingBoxFor repositionMe
    didMove = no

    if (MathHelper.divisibleBy newElementBox.left, grid[0]) and axis in ['both', 'x']
      repositionMe.style.left = "#{newElementBox.left}px"
      didMove = yes
      
    if (MathHelper.divisibleBy newElementBox.top, grid[1]) and axis in ['both', 'y']
      repositionMe.style.top = "#{newElementBox.top}px" 
      didMove = yes
      
    if didMove and (@options.dragHelper.indexOf 'anchor') isnt -1
      xDiff = newElementBox.left - elementBoundingBox.left
      yDiff = newElementBox.top - elementBoundingBox.top
      
      _.each (@figureOutAnchors repositionMe, @options.dragAnchorElements), (element) =>
        box = DOMHelper.getBoundingBoxFor element
        element.style.left = "#{box.left+xDiff}px"
        element.style.top = "#{box.top+yDiff}px"
        
    DOMHelper.stopEvent event
    
  # Prepare an element for being a sortable container
  setupSort: ->
    
    # it is technically both a drop and sort zone
    @dropZones.push @
    @sortZones.push @
    @containedElements = []
    @_dropSorts = []
    @isSort = true

    # set up a draggable DropSort on all of our children
    childrenNodes = @element.querySelectorAll _.result @options, 'sortSelector'
    _.each childrenNodes, (node) =>
      
      draggableSortItemOptions = 
        dragHelper: 'clone'
        dropTolerance: 'pointer'
        doSort: no
      
      options = _.extend (_.clone @optionsCopy), draggableSortItemOptions

      dropSort = new DropSort node, options
        
      @_dropSorts.push dropSort
      dropSort._sortable = @
      
  # Prepare an element for being a dropzone
  setupDrop: ->
    @dropZones.push @
    @containedElements = []
    
  # Prepare an element to be dragged
  setupDrag: ->
    
    # touch support!
    target = if _.result @options, 'touchEnabled' then @element else document
    
    # do a lot of stuff when we click, and even more if we hold!
    @mouse.on 'down', @_down = (e) =>
      #left mouse click, or a touch
      return if not ((window.event and e.button is 1) or e.button is 0 or _.result @options, 'touchEvents')
      return if _.result @options, 'dragDisabled'
      
      handle = _.result @options, 'dragHandleClassName'
      return if handle and ((DOMHelper.getClasses DOMHelper.getEventTarget e).indexOf handle) is -1
        
      DOMHelper.stopEvent e
      
      @_mouseDown = yes
      
      eventCopy = {}
      eventCopy[i] = e[i] for i of e #it's an IE joke, because you know, IE

      setTimeout =>
        # in this case we only clicked instead of held the mouse
        if not @_mouseDown
          @_sortable.options.sortElementClick @_sortable, @, eventCopy if @_sortable
          return
        
        else if @_sortable
          @select()
          
        @removeElementFromDropzones()
        
        # prepare an element to be dragged
        @element.style.zIndex = _.result @options, 'dragZIndex'
        DOMHelper.addClass @element, _.result @options, 'dragClass'
        @dragging = true
        @dragElement = @getDragItem eventCopy
        @dragStartPosition = DOMHelper.getBoundingBoxFor @element
        @dragStartPosition._origMouseX = eventCopy.pageX
        @dragStartPosition._origMouseY = eventCopy.pageY
        
        # build a placeholder element if the @_sortable instance has a custom one
        if @_sortable
          
          @_sortPlaceholder = _.result @options, 'sortPlaceholder'
          
          throw new Error errorMsgs.badHolder if not _.isElement @_sortPlaceholder
        
          @storeDisplay()
        
        do @options.dragStartCallback?.bind @
          
      , _.result @options, 'dragDelay'
      
    # do a bunch of stuff when we let go of the mouse (if we were dragging)
    @mouse.on 'up', @_up = (e) =>
      @_mouseDown = no
      return if not @dragging # don't trigger other DropSorts
      @element.style.zIndex = @element._zIndex
      DOMHelper.removeClass @element, _.result @options, 'dragClass'
      @dragging = false
      delete @dragStartPosition
      
      if @element isnt @dragElement
        @element.parentNode.removeChild @dragElement
        @element.style.left = @dragElement.style.left
        @element.style.top = @dragElement.style.top
      
      @handleDropZones e
      
      currentlySelected = []
      
      if @_sortable
        @restoreDisplay()
        
        oldSortable = @_sortable
        currentlySelected = @finishSortDrop()
        newSortable = @_sortable
        
        oldSortable.resetDropsorts()
        newSortable.resetDropsorts()
        
      do @options.dragUpCallback?.bind @, currentlySelected
      
      @mouse.off 'move', @_move
      
      @_sortable.options.sortRubberBand @ if @_sortable
    , target
      
    # reposition the item when we move the mouse
    @mouse.on 'move', @_move = (e) =>
      return if not @dragging
      minDragDistance = _.result @options, 'minDragDistance'
      return if (Math.abs @dragStartPosition._origMouseX-e.x) < minDragDistance or
                (Math.abs @dragStartPosition._origMouseY-e.y) < minDragDistance
      @repositionItem e, @dragElement
      @handleDropZones e, callback='hover'
      @handleSortZones e
    , target
    
  # Add the DropSort binding to the element
  addBinding: ->
    throw new Error errorMsgs.multiBind if @element.bindingId
    @element.bindingId = _.uniqueId 'ds-'

  # Get the item that should appear under the cursor
  getDragItem: (e) ->
    if @_sortable
      placeholderFunc = @_sortable.options.sortDragPlaceholder?.bind @_sortable
      element = placeholderFunc()
      
      if _.isElement element
        @element.parentNode.insertBefore element, @element
        DOMHelper.movePositionProperties @element, element
        return element
        
      else if not _.isUndefined element
        console.error "sortDragPlaceholder: Not a real element, skipping this attempt and using 'clone' instead" if not _.isElement element
    
    return DOMHelper.clone @element if (@options.dragHelper.indexOf "clone") isnt -1
      
    return @element if (@options.dragHelper.indexOf "original") isnt -1
          
  # remove an element from existing dropzones (if it was previosuly contained in one)
  removeElementFromDropzones: ->
    _.each @dropZones, (dropZone) =>
      dropZone.containedElements = _.without dropZone.containedElements, @element
      newClassName =  _.result dropZone.options, 'dropClass'
      DOMHelper.removeClass dropZone.element, newClassName if dropZone.containedElements.length is 0
    
  # Manage the dropzones
  handleDropZones: (e, callback = 'drop') ->
    
    return if @dropZones.length is 0
    
    # different callback depending on the action
    callbacks =
      drop: (dropZone) =>
        newClassName =  _.result dropZone.options, 'dropClass'
        (DOMHelper.addClass dropZone.element, newClassName) if not DOMHelper.hasClass dropZone.element, newClassName
        dropZone.containedElements.push @element
        @options.dropCallback?()
        
      hover: (dropZone) =>
        newClassName = _.result dropZone.options, 'dropHoverClass'
        (DOMHelper.addClass dropZone.element, newClassName) if not DOMHelper.hasClass dropZone.element, newClassName
        @options.dropHoverCallback?()
        
    # find some dropZones to run these callbacks on
    _(@dropZones)
      .reject (dropZone) ->
        dropZone.isSort
        
      .each (dropZone) ->
        DOMHelper.removeClass dropZone.element, _.result dropZone.options, 'dropHoverClass'
        
      .reject (dropZone) =>
        (_.result dropZone.options, 'dropDisabled') or not dropZone.options.canDropOn @element
        
      .filter (dropZone) ->
        dropZone.doesIntersect dropZone.element, e
        
      .filter (dropZone) =>
        dropAccept = _.result dropZone.options, 'dropAccept'
        not dropAccept or _.contains (document.querySelectorAll dropAccept), @element
        
      .each callbacks[callback]
      
  # similar to handleDropZones, except it only runs with sortZones
  handleSortZones: (event) ->
    _(@sortZones)
      .filter (sortZone) ->
        sortZone.doesIntersect sortZone.element, event
        
      .reject (sortZone) ->
        _.result sortZone.options, 'sortDisabled'
        
      .filter (sortZone) =>
        selector = _.result sortZone.options, 'sortAcceptSelector'
        sortZone is @element._sortable or @element.matches selector
        
      .each (sortZone) =>
        
        # if pointerEvents acts up, change this to display: none instead!
        oldPointerEvents = @dragElement.style.display
        @dragElement.style.display = 'none'
        hoveringNode = document.elementFromPoint event.clientX,event.clientY
        @dragElement.style.display = oldPointerEvents
      
        if (sortZone.element isnt hoveringNode) and 
            (sortZone.element.contains hoveringNode) and 
            (@_sortPlaceholder isnt hoveringNode) and
            @doesIntersectTarget hoveringNode, @element, event

          sortZone.element.removeChild @_sortPlaceholder if sortZone.element.contains @_sortPlaceholder
          
          orient = _.result @options, 'orientation'
          
          [useFunc, primaryArg] = DOMSpatialHelper.getHoveredItemHalf hoveringNode, event, orient

          sortZone.element[useFunc] @_sortPlaceholder, primaryArg
      
  # do some final actions when you drop into a sortable (multi sort, mostly)
  finishSortDrop: ->
    
    companions = @_sortable.getSelected()

    _.each @sortZones, (sortZone) =>
      
      # find the right sort zone
      if sortZone.element.contains @_sortPlaceholder
        @_sortable = sortZone

        # clone it so we can get a copy of the old array for the drop function
        selected = _.clone companions.reverse()
        parent = @_sortPlaceholder
        
        while item = selected.shift()
          sortZone.element.insertBefore item.element, parent
          item.select()
          item._sortable = sortZone
          parent = item.element
        
        sortZone.element.removeChild @_sortPlaceholder
        
    companions
        
  # check if an element intersects with an event
  doesIntersect: (baseEl, event) ->
    @doesIntersectTarget baseEl, (DOMHelper.getEventTarget event), event
    
  # check if an element intersects with a target element
  doesIntersectTarget: (baseEl, target, event) ->
    
    targetBox = DOMHelper.getBoundingBoxFor target

    mode = _.result @options, 'dropTolerance'
    mouseBox = 
      offsetX: event.clientX
      offsetY: event.clientY
      offsetWidth: 1
      offsetHeight: 1
    
    getContained = (targetContainer) =>
      @checkHowContainedIs targetContainer, DOMHelper.getBoundingBoxFor baseEl
    
    switch mode
      when 'fit' then return true if getContained(targetBox).pointsContained.length is 4
      when 'touch' then return true if getContained(targetBox).pointsContained.length > 0
      when 'pointer' then return true if getContained(mouseBox).pointsContained.length > 0
      when 'intersect' then #TODO
      
    return false
    
  # store the existing display settings for use later
  storeDisplay: ->
    @element.style._display = @element.style.display
    
  # hide the element from view
  hideDisplay: ->
    @element.style.display = 'none'
    
  # restore the elements display settings from the saved version
  restoreDisplay: ->
    @element.style.display = @element.style._display
    
  # call condition: descendant of sortable
  # toggle the selected status of an element
  toggle: ->
    throw new Error errorMsgs.noSorting if not @_sortable
    selectedClass = _.result @_sortable.options, 'sortSelectedClass'
    
    if DOMHelper.hasClass @element, selectedClass
      do @unselect
    else
      do @select
      
  # call condition: descendant of sortable
  # select the element
  select: ->
    throw new Error errorMsgs.noSorting if not @_sortable
    @_isSortSelected = yes
    selectedClass = _.result @_sortable.options, 'sortSelectedClass'
    DOMHelper.addClass @element, selectedClass
    
  # call condition: descendant of sortable
  # unselect the element
  unselect: ->
    throw new Error errorMsgs.noSorting if not @_sortable
    @_isSortSelected = no
    selectedClass = _.result @_sortable.options, 'sortSelectedClass'
    DOMHelper.removeClass @element, selectedClass
      
  # call condition: descendant of sortable
  # check if an item is selected
  isSelected: ->
    throw new Error errorMsgs.noSorting if not @_sortable
    @_isSortSelected
    
  # call condition: sortable
  # count all of the selected items in a sortable
  countSelected: ->
    throw new Error errorMsgs.isNotSort if not @isSort
    @getSelected().length
    
  # call condition: sortable
  # get all of the selected items in a sortable
  getSelected: ->
    throw new Error errorMsgs.isNotSort if not @isSort
    _.filter @_dropSorts, (draggable) -> draggable._isSortSelected
    
  # call condition: sortable
  # unselect all items in a sortable
  unselectAll: ->
    do @unselectRange
    
  # call condition: sortable
  # select all items in a sortable
  selectAll: ->
    do @selectRange
    
  # call condition: sortable
  # alias for getChildrenRange with no params (ie, all children)
  getChildren: ->
    @getChildrenRange()
    
  # call condition: sortable
  # get all children in a particular range
  getChildrenRange: (start = 0, finish) ->
    throw new Error errorMsgs.isNotSort if not @isSort
    
    [first, ..., last] = @_dropSorts
    
    # pull them out of the array if we're given numerical indexes
    if not _.isNumber start
      index = @_dropSorts.indexOf start
      throw new Error errorMsgs.poorIndex if index is -1
      start = index
      
    if _.isUndefined finish
      finish = @_dropSorts.indexOf last
      
    if not _.isNumber finish
      index = @_dropSorts.indexOf start
      throw new Error errorMsgs.poorIndex if index is -1
      start = index
    
    @_dropSorts[start..finish]

  # call condition: sortable
  # select all children in a particular range
  selectRange: (start = 0, finish) ->
    _.each (@getChildrenRange start, finish), (dropSort) -> dropSort.select()
    
  # call condition: sortable
  # unselect all children in a particular range
  unselectRange: (start = 0, finish) ->
    _.each (@getChildrenRange start, finish), (dropSort) -> dropSort.unselect()
    
  # call condition: sortable
  # toggle the selected status of a particular range of elements
  toggleRange: (start = 0, finish) ->
    _.each (@getChildrenRange start, finish), (dropSort) -> dropSort.toggle()
    
  # call condition: sortable
  # reset the dropsorts contained by this element
  resetDropsorts: ->
    throw new Error errorMsgs.isNotSort if not @isSort
    
    @_dropSorts = _(@element.childNodes)
      .filter (el) -> not _.isUndefined el._dropSort?._isSortSelected
      .map (el) -> el._dropSort
      .value()
    
# check the actual containment vector of checkMe re: box
DropSort::checkHowContainedIs = (checkMe, box) ->
  checkBox = 
    top: checkMe.offsetY
    left: checkMe.offsetX 
    right: checkMe.offsetX + checkMe.offsetWidth
    bottom: checkMe.offsetY + checkMe.offsetHeight
    
  boxBox =
    top: box.offsetY
    left: box.offsetX
    right: box.offsetX + box.offsetWidth
    bottom: box.offsetY + box.offsetHeight
    
  containedSides =
    contain: "none"
    pointsContained: []
  
  polygon = [
    [boxBox.left, boxBox.top]
    [boxBox.left, boxBox.bottom]
    [boxBox.right, boxBox.bottom]
    [boxBox.right, boxBox.top]
  ]
  
  points =
    tL: [checkBox.left, checkBox.top]
    tR: [checkBox.right, checkBox.top]
    bR: [checkBox.right, checkBox.bottom]
    bL: [checkBox.left, checkBox.bottom]
    
  for name,pt of points
    containedSides.pointsContained.push pt if MathHelper.pointInPolygon pt, polygon
    
  containedSides.contain = "partial" if containedSides.pointsContained.length > 0
  containedSides.contain = "full" if containedSides.pointsContained.length is 4
  containedSides
                    
# Get all anchor items (dragged with this item) for an element
DropSort::figureOutAnchors = (element, anchorOpt) ->
  anchors = []
  anchors.push anchorOpt if _.isElement anchorOpt
  anchors = document.querySelectorAll anchorOpt if _.isString anchorOpt
  anchors = anchorOpt if _.isArray anchorOpt
  anchors
  
# Check if element is contained by container, and if not, change its bounds so it is
DropSort::isElementContainedChangePos = (element, container) -> 

  if (_.isNumber container.left) and (element.left < container.left)
    element.left = container.left
    
  if (_.isNumber container.top) and element.top < container.top
    element.top = container.top
    
  if (_.isNumber container.rightCalc) and element.right > container.rightCalc
    element.left = container.rightCalc-element.offsetWidth
    
  if (_.isNumber container.bottomCalc) and element.bottom > container.bottomCalc
    element.top = container.bottomCalc-element.offsetHeight
    
  element
  
# array of all droppable zones managed by DropSort
DropSort::dropZones = []

# array of all sortable instances managed by DropSort
DropSort::sortZones = []

# Export it to the appropriate place
root = exports ? @
root.DropSort = DropSort