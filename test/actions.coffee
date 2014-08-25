
class Action
  constructor: (@type, @element) ->
    @init()
  
  # set up events for each type of action
  init: ->
    touchEvents = ['touchstart', 'touchmove', 'touchend']
    baseIgnoreEvents = ['click', 'drag']
    @ignoreEvents = touchEvents.concat baseIgnoreEvents
    
  # nothing happens!
  destroy: ->

  # abstract away adding an event listener
  on: (type, handler, target = @element) ->
    type = "#{@type}#{type}" if not (type.indexOf @type is 0) or (type not in @ignoreEvents)
    @off type if @[type]
    
    bound = no
    if document.addEventListener
      target.addEventListener type, handler
      bound = yes
      
    (target.attachEvent "on#{type}", handler) if document.attachEvent and not bound
    console.error "Could not bind event #{type}" if not document.addEventListener or not document.attachEvent
    
  # abstract away removing an event listener
  off: (type, handler, target = @element) ->
    type = "#{@type}#{type}" if not (type.indexOf @type is 0) or (type not in @ignoreEvents)
    
    unbound = no
    if document.removeEventListener
      target.removeEventListener type, handler
      unbound = yes
      
    (target.detachEvent "on#{type}", handler) if document.detachEvent and not unbound
    console.error "Could not unbind event #{type}" if not document.removeEventListener or not document.detachEvent

class DragAction extends Action
  constructor: (@element) ->
    super 'drag', @element

class MouseAction extends Action
  constructor: (@element) ->
    super 'mouse', @element
    
root = exports ? @
root.MouseAction = MouseAction
root.DragAction = DragAction