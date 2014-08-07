
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
    
root = exports ? @
root.MouseAction = MouseAction
root.DragAction = DragAction