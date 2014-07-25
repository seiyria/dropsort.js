
class Action
  constructor: (@type, @element) ->
    @init()
  
  init: ->
    touchEvents = ['touchstart', 'touchmove', 'touchend']
    baseIgnoreEvents = ['click', 'drag']
    @ignoreEvents = touchEvents.concat baseIgnoreEvents
    
  destroy: ->

  on: (type, handler, target = @element) ->
    type = "#{@type}#{type}" if not (type.indexOf @type is 0) or (type not in @ignoreEvents)
    @off type if @[type]
    
    (target.addEventListener type, handler) if document.addEventListener
    (target.attachEvent "on#{type}", handler) if document.attachEvent
    console.error "Could not bind event #{type}" if not document.addEventListener or document.attachEvent
    
  off: (type, handler, target = @element) ->
    type = "#{@type}#{type}" if not (type.indexOf @type is 0) or (type not in @ignoreEvents)
    
    (target.removeEventListener type, handler) if document.removedEventListener
    (target.detachEvent "on#{type}", handler) if document.detachEvent
    console.error "Could not unbind event #{type}" if not document.removeEventListener or document.detachEvent

class DragAction extends Action
  constructor: (@element) ->
    super 'drag', @element

class MouseAction extends Action
  constructor: (@element) ->
    super 'mouse', @element
    
class DropSort
  errorMsgs = 
    noElement: 'You have to specify an element to attach DropSort to'
    staticPos: 'You cannot use DropSort on an element with position: static set'
    invalidEl: 'Could not get the container for element'
    multiBind: 'You cannot bind to the same element multiple times'
    gridDimen: 'Your grid dimensions are invalid. They must be integers greater than 1'
    badHelper: 'You must specify a valid helper (it must be a function that returns a DOMElement, contain "clone" or "original")'
    noActions: 'You must specify an action (doDrag, doDrop, or doSort)'
    
  constructor: (@element, optionsSpecified = {}) ->

    throw new Error errorMsgs.noElement if not @element
    throw new Error errorMsgs.staticPos if @getStyle(@element, 'position') is 'static'
    
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
      
      # what class should I get while I'm hovered over?
      # dropHoverClass: 'ds-drop-hover'
      
      ## TODO hover events (class, check for intersect)
      
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
      
      dropCallback: ->
      dropHoverCallback: ->

    do @doInitialVariableCalculations
    do @addBinding
    @mouse = new MouseAction @element

    if _.result @options, 'doDrop'
      do @setupDrop
      
    else if _.result @options, 'doDrag'
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
    @element._zIndex = @getStyle @element, 'z-index'

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
      
    if grid[0] < 1 or not @divisibleBy grid[0] or grid[1] < 1 or not @divisibleBy grid[1]
      throw new Error errorMsgs.gridDimen
      
    @options.dragGrid = grid
      
  # Get the bounding box for the current container element (if no container is set, it will use the parent of the element)
  getContainerBoundingBox: ->
    type = _.result @options, 'dragContainerType'
    return if type is null
    
    if type is 'parent'
      type = @element.parentNode
      
    if  _.isElement type
      @options.dragContainerBox = @getBoundingBoxFor type
      
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
      windowSize = @getWindowSize()
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
    
    elementBoundingBox = @getBoundingBoxFor repositionMe
    didMove = no

    if (@divisibleBy newElementBox.left, grid[0]) and axis in ['both', 'x']
      repositionMe.style.left = "#{newElementBox.left}px"
      didMove = yes
      
    if (@divisibleBy newElementBox.top, grid[1]) and axis in ['both', 'y']
      repositionMe.style.top = "#{newElementBox.top}px" 
      didMove = yes
      
    if didMove and (@options.dragHelper.indexOf 'anchor') isnt -1
      xDiff = newElementBox.left - elementBoundingBox.left
      yDiff = newElementBox.top - elementBoundingBox.top
      
      _.each (@figureOutAnchors repositionMe, @options.dragAnchorElements), (element) =>
        box = @getBoundingBoxFor element
        element.style.left = "#{box.left+xDiff}px"
        element.style.top = "#{box.top+yDiff}px"
    
    @stopEvent event
    
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
      return if handle and ((@getClasses @getEventTarget e).indexOf handle) is -1
        
      @stopEvent e
      
      @removeElementFromDropzones()
      
      @element.style.zIndex = _.result @options, 'dragZIndex'
      @addClass @element, _.result @options, 'dragClass'
      @dragging = true
      @dragElement = @getDragItem e
      @dragStartPosition = @getBoundingBoxFor @element
      @dragStartPosition._origMouseX = e.pageX
      @dragStartPosition._origMouseY = e.pageY
      
    @mouse.on 'up', @_up = (e) =>
      return if not @dragging # don't trigger other DropSorts
      @element.style.zIndex = @element._zIndex
      @removeClass @element, _.result @options, 'dragClass'
      @dragging = false
      delete @dragStartPosition
      
      if @element isnt @dragElement
        @element.parentNode.removeChild @dragElement
        @element.style.left = @dragElement.style.left
        @element.style.top = @dragElement.style.top
      
      @handleDropZones e
      @mouse.off 'move', @_move
    , target
      
    @mouse.on 'move', @_move = (e) =>
      return if not @dragging
      minDragDistance = _.result @options, 'minDragDistance'
      return if (Math.abs @dragStartPosition._origMouseX-e.x) < minDragDistance or
                (Math.abs @dragStartPosition._origMouseY-e.y) < minDragDistance
      @repositionItem e, @dragElement
      @handleDropZones e, callback='hover'
    , target
    
  # Add the DropSort binding to the element
  addBinding: ->
    throw new Error errorMsgs.multiBind if @element.bindingId
    @element.bindingId = _.uniqueId 'ds-'

  # Get the item that should appear under the cursor
  getDragItem: (e) ->
    if (@options.dragHelper.indexOf "clone") isnt -1
      clone = @element.cloneNode true
      box = @getBoundingBoxFor @element
      @element.parentNode.insertBefore clone, @element
      @element.style.left = clone.style.left = box.offsetX+'px'
      @element.style.top = clone.style.top = box.offsetY+'px'
      @element.style.position = clone.style.position = 'absolute'
      
      return clone
      
    return @element if (@options.dragHelper.indexOf "original") isnt -1
    
  # Manage the dropzones
  handleDropZones: (e, callback = 'drop') ->
    
    return if @dropZones.length is 0
    
    callbacks =
      drop: (dropZone) =>
        newClassName =  _.result dropZone.options, 'dropClass'
        (dropZone.addClass dropZone.element, newClassName) if not dropZone.hasClass dropZone.element, newClassName
        dropZone.containedElements.push @element
        @options.dropCallback?()
        
      hover: (dropZone) =>
        newClassName = _.result dropZone.options, 'dropHoverClass'
        (dropZone.addClass dropZone.element, newClassName) if not dropZone.hasClass dropZone.element, newClassName
        @options.dropHoverCallback?()
        
    _(@dropZones)
      .each (dropZone) ->
        dropZone.removeClass dropZone.element, _.result dropZone.options, 'dropHoverClass'
      .reject (dropZone) =>
        (_.result dropZone.options, 'dropDisabled') or not dropZone.options.canDropOn @element
      .filter (dropZone) ->
        dropZone.doesIntersect dropZone.element, e
      .filter (dropZone) =>
        dropAccept = _.result dropZone.options, 'dropAccept'
        not dropAccept or _.contains (document.querySelectorAll dropAccept), @element
      .each callbacks[callback]
  
  removeElementFromDropzones: ->
    _.each @dropZones, (dropZone) =>
      dropZone.containedElements = _.without dropZone.containedElements, @element
      newClassName =  _.result dropZone.options, 'dropClass'
      @removeClass dropZone.element, newClassName if dropZone.containedElements.length is 0

  doesIntersect: (dropZone, event) ->
    mode = _.result @options, 'dropTolerance'
    target = @getEventTarget event
    
    targetBox = @getBoundingBoxFor target
    mouseBox = 
      offsetX: event.clientX
      offsetY: event.clientY
      offsetWidth: 1
      offsetHeight: 1
    
    getContained = (targetContainer) =>
      @checkHowContainedIs targetContainer, @getBoundingBoxFor dropZone
    
    switch mode
      when 'fit' then return true if getContained(targetBox).pointsContained.length is 4
      when 'touch' then return true if getContained(targetBox).pointsContained.length > 0
      when 'pointer' then return true if getContained(mouseBox).pointsContained.length > 0
      when 'intersect' then #TODO
      
    return false

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
    containedSides.pointsContained.push pt if @pointInPolygon pt, polygon
    
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
    
# Check it num is divisible by divisor
DropSort::divisibleBy = (num, divisor = 1) ->
  num % divisor is 0
  
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
  
# TODO convert to coffee
DropSort::pointInPolygon = `function (point, vs) {
    // ray-casting algorithm based on
    // http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
    
    var x = point[0], y = point[1];
    
    var inside = false;
    for (var i = 0, j = vs.length - 1; i < vs.length; j = i++) {
        var xi = vs[i][0], yi = vs[i][1];
        var xj = vs[j][0], yj = vs[j][1];
        
        var intersect = ((yi > y) != (yj > y))
            && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
    }
    
    return inside;
}`

#check if element is contained
DropSort::isElementContainedBy = (element, container) ->
  (container.bottom and element.bottom <= container.bottom) and
  (container.right and element.right <= container.right) and
  (container.left and element.left >= container.left) and
  (container.top and element.top >= container.top)
  
# Get the window size 
DropSort::getWindowSize = ->
  de = document.documentElement
  body = document.getElementsByTagName('body')[0]
  {
    x: window.innerWidth or de.clientWidth or body.clientWidth
    y: window.innerHeight or de.clientHeight or body.clientHeight
  }

# Get a style property from an element
DropSort::getStyle = (elem, prop) ->
  return elem.currentStyle[prop] if elem.currentStyle
  return window.getComputedStyle(elem).getPropertyValue prop if window.getComputedStyle
  return elem.style[prop] if elem.style

# Get the bounding box for an element
DropSort::getBoundingBoxFor = (elem) ->
  base =
    offsetX: 0
    offsetY: 0
    offsetHeight: elem.offsetHeight
    offsetWidth: elem.offsetWidth
    bottom: parseFloat @getStyle elem, 'bottom'
    right: parseFloat @getStyle elem, 'right'
    left: parseFloat @getStyle elem, 'left'
    top: parseFloat @getStyle elem, 'top'
  
  base.bottomCalc = elem.offsetHeight
  base.rightCalc = elem.offsetWidth
  
  for attr, val of base
    base[attr] = 0 if _.isNaN val
    
  if elem.offsetParent
    add = ->
      base.offsetX += elem.offsetLeft
      base.offsetY += elem.offsetTop
    add()
    add() while elem = elem.offsetParent
  
  base
  
# array of all droppable zones managed by DropSort
DropSort::dropZones = []
  
# map of _.uniqueId to DOMElement
#DropSort::bindings = {}

# stop an event by whatever means it has available
DropSort::stopEvent = (event) ->
  event.preventDefault() if event.preventDefault
  event.stopPropagation() if event.stopPropagation
  event.returnvalue = false
  
DropSort::hasClass = (el, className) ->
  (@getClasses(el).indexOf className) isnt -1
  
# Get all classes for el
DropSort::getClasses = (el) ->
  el.className

# add a class to an element
DropSort::addClass = (el, newClass) ->
  if el.classList
    el.classList.add newClass
  else
    el.className += " #{newClass}"
  
# remove a class from an element
DropSort::removeClass = (el, oldClass) ->
  if el.classList
    el.classList.remove oldClass
  else
    el.className = el.className.replace new RegExp('(^|\\b)' + oldClass.split(' ').join('|') + '(\\b|$)', 'gi'), ' '

# get the current target of the element
DropSort::getEventTarget = (event) ->
  target = event.target
  target = event.srcElement if event.srcElement
  target = target.parentNode if target.nodeType is 3
  
  target
  
# get the current position of the item on the page
DropSort::getPosition = (event) ->
  return {x: event.targetTouches[0].pageX, y: event.targetTouches[0].pageY} if event.targetTouches
  return {x: event.pageX, y: event.pageY} if event.pageX or event.pageY
  
  db = document.body
  de = document.documentElement
  return {x: event.clientX + db.scrollLeft + de.scrollLeft, y: event.pageY + db.scrollTop + de.scrollTop} if event.clientX or event.clientY
  {x: 0, y: 0}

# Export it to the appropriate place
root = exports ? @
root.DropSort = DropSort