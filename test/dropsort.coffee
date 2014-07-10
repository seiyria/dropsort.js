
# Lots of parameters could be interpreted as either function or object or w/e
#   Due to _.result being fabulous

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
  constructor: (@element, optionsSpecified = {}) ->
    
    throw new Error('You have to specify an element to attach DropSort to') if not @element
    throw new Error('You cannot use DropSort on an element with position: static set') if @getStyle(@element, 'position') is 'static'
    
    @options = _.defaults optionsSpecified,
      touchEnabled: 'ontouchstart' in window
      
      # string or function (???)
      dragClass: 'ds-drag'
      anchor: @element
      
      dragOpts:
        # either an array, a selector, or a function (???)
        anchorElements: []
        
        container:
          # either 'parent' or 'window' or a function (???)
          type: 'parent'
          
          # object or function (???)
          box:
            bottom: null
            right: null
            left: null
            top: null
            
      dropOpts: {}
      sortOpts: {}
      
    @addBinding()
    @mouse = new MouseAction @element

    # need some form of esay way to determine what to call
    @setupDrag() 

  repositionItem: (event) ->

    offsetX = event.pageX
    offsetY = event.pageY
    
    if not (@dragStartPosition._xDiff or @dragStartPosition._yDiff)
      @dragStartPosition._xDiff = @dragStartPosition.left - offsetX
      @dragStartPosition._yDiff = @dragStartPosition.top - offsetY
      
    newX = offsetX + @dragStartPosition._xDiff
    newY = offsetY + @dragStartPosition._yDiff
      
    #console.log @dragStartPosition
      
    #do bounds checking here when that option is implemented
    
    @element.style.left = "#{newX}px"
    @element.style.top = "#{newY}px"
    
    @stopEvent event
    
  # Prepare an element to be dragged
  setupDrag: ->
    target = if _.result @options, 'touchEnabled' then @element else document
    @mouse.on 'down', @_down = (e) =>
      return if not ((window.event and e.button is 1) or e.button is 0 or _.result @options, 'touchEvents')
      @stopEvent e
      @addClass @element, _.result @options, 'dragClass'
      @dragging = true
      @dragStartPosition = @getElPosAndOffset @element
      @dragStartPosition._origMouseX = e.pageX
      @dragStartPosition._origMouseY = e.pageY

    @mouse.on 'up', @_up = (e) => 
      @removeClass @element, _.result @options, 'dragClass'
      @dragging = false
      delete @dragStartPosition
      @mouse.off 'move', @_move
    , target
      
    @mouse.on 'move', @_move = (e) =>
      return if not @dragging
      @repositionItem e
    , target
    
  addBinding: ->
    throw new Error('You cannot bind on the same element twice') if @element.bindingId
    @element.bindingId = _.uniqueId 'ds-'
    @bindings[@element.bindingId] = @element
  
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
DropSort::getElPosAndOffset = (elem) ->
  base =
    offsetX: 0
    offsetY: 0
    bottom: parseFloat @getStyle elem, 'bottom'
    right: parseFloat @getStyle elem, 'right'
    left: parseFloat @getStyle elem, 'left'
    top: parseFloat @getStyle elem, 'top'
  
  for attr, val of base
    base[attr] = 0if _.isNaN val
    
  if elem.offsetParent
    add = ->
      base.offsetX += elem.offsetLeft
      base.offsetY += elem.offsetTop
    add()
    add() while elem = elem.offsetParent
  
  base
  
# map of _.uniqueId to DOMElement
DropSort::bindings = {}

# stop an event by whatever means it has available
DropSort::stopEvent = (event) ->
  event.preventDefault() if event.preventDefault
  event.stopPropagation() if event.stopPropagation
  event.returnvalue = false

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