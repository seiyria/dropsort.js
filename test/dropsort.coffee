
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
    
  constructor: (@element, optionsSpecified = {}) ->

    throw new Error errorMsgs.noElement if not @element
    throw new Error errorMsgs.staticPos if DOMHelper.getStyle(@element, 'position') is 'static'
    
    @options = _.defaults optionsSpecified,
    
      doDrag: true
    
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
      dropTolerance: 'pointer'
      
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

    do @doInitialVariableCalculations
    do @addBinding

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
    @getContainerBoundingBox()
    @checkGrid()
    @setAxis()
    @setBaseZIndex()
    @checkIfHelperIsValid()
    
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
    @dropZones.push @
    @sortZones.push @
    @containedElements = []
    @_dropSorts = []
    @isSort = true

    childrenNodes = @element.querySelectorAll _.result @options, 'sortSelector'
    _.each childrenNodes, (node) =>
      dropSort = new DropSort node, dragHelper: "clone"
      @_dropSorts.push dropSort
      dropSort._sortable = @
      
  # Prepare an element for being a dropzone
  setupDrop: ->
    @dropZones.push @
    @containedElements = []
    
  # Prepare an element to be dragged
  setupDrag: ->
    target = if _.result @options, 'touchEnabled' then @element else document
    @mouse.on 'down', @_down = (e) =>
      #left mouse click, or a touch
      return if not ((window.event and e.button is 1) or e.button is 0 or _.result @options, 'touchEvents')
      return if _.result @options, 'dragDisabled'
      
      handle = _.result @options, 'dragHandleClassName'
      return if handle and ((DOMHelper.getClasses DOMHelper.getEventTarget e).indexOf handle) is -1
        
      DOMHelper.stopEvent e
      
      @removeElementFromDropzones()
      
      @element.style.zIndex = _.result @options, 'dragZIndex'
      DOMHelper.addClass @element, _.result @options, 'dragClass'
      @dragging = true
      @dragElement = @getDragItem e
      @dragStartPosition = DOMHelper.getBoundingBoxFor @element
      @dragStartPosition._origMouseX = e.pageX
      @dragStartPosition._origMouseY = e.pageY
      
      if @_sortable
        
        @_sortPlaceholder = _.result @options, 'sortPlaceholder'
        
        if not _.isElement @_sortPlaceholder
          throw new Error errorMsgs.badHolder
          
        @element.style._display = @element.style.display
        @element.style.display = 'none'
      
    @mouse.on 'up', @_up = (e) =>
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
      
      if @_sortable
        @element.style.display = @element.style._display
        @removePlaceholderFromSortzones()
      
      @mouse.off 'move', @_move
      
      @_sortable.options.sortRubberBand @ if @_sortable
    , target
      
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
    return DOMHelper.clone @element if (@options.dragHelper.indexOf "clone") isnt -1
      
    return @element if (@options.dragHelper.indexOf "original") isnt -1
    
  # Manage the dropzones
  handleDropZones: (e, callback = 'drop') ->
    
    return if @dropZones.length is 0
    
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
        
    _(@dropZones)
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
      
  handleSortZones: (e) ->
    _(@sortZones)
      .filter (sortZone) ->
        sortZone.doesIntersect sortZone.element, e
      .each (sortZone) =>
        
        ## DO NOT REMOVE
        ## if pointerEvents acts up, change this to display: none instead!
        oldPointerEvents = @element.style.pointerEvents
        @element.style.pointerEvents = 'none'
        hoveringNode = document.elementFromPoint event.x,event.y
        @element.style.pointerEvents = oldPointerEvents
      
        if (sortZone.element isnt hoveringNode) and 
            (sortZone.element.contains hoveringNode) and 
            (@_sortPlaceholder isnt hoveringNode) and
            @doesIntersectTarget hoveringNode, @element

          sortZone.element.removeChild @_sortPlaceholder if sortZone.element.contains @_sortPlaceholder
          
          orient = _.result @options, 'orientation'
          
          [useFunc, primaryArg] = DOMSpatialHelper.getHoveredItemHalf hoveringNode, e, orient
          
          #return if primaryArg.nodeType is 3
          
          #console.log primaryArg.nodeType, hoveringNode.nodeType, hoveringNode is primaryArg, hoveringNode.nextSibling is primaryArg, useFunc
            
          sortZone.element[useFunc] @_sortPlaceholder, primaryArg
          
          #oldEl = sortZone.element.removeChild @element
          #sortZone.element[useFunc] oldEl, primaryArg
          
  removeElementFromDropzones: ->
    _.each @dropZones, (dropZone) =>
      dropZone.containedElements = _.without dropZone.containedElements, @element
      newClassName =  _.result dropZone.options, 'dropClass'
      DOMHelper.removeClass dropZone.element, newClassName if dropZone.containedElements.length is 0
      
  removePlaceholderFromSortzones: ->
    _.each @sortZones, (sortZone) =>
      if sortZone.element.contains @_sortPlaceholder
        sortZone.element.insertBefore @element, @_sortPlaceholder
        sortZone.element.removeChild @_sortPlaceholder

  doesIntersect: (baseEl, event) ->
    @doesIntersectTarget baseEl, DOMHelper.getEventTarget event
    
  doesIntersectTarget: (baseEl, target) ->
    
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
      
# Get all anchors for an element
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