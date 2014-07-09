
# Should dependencies be bundled with this when distributing it? ie, lodash & eventemitter2

# Is it better to make a monolithic class or
#   DropSort.Sort, DropSort.Drag, DropSort.Dtop? 
#   How would the latter be architected?

# Lots of parameters could be interpreted as either function or object or w/e
#   Due to _.result being fabulous

class DropSort extends EventEmitter2
  constructor: (@element, optionsSpecified) ->

    # We don't need to pass anything to EventEmitter2
    super {}
    
    @options = _.defaults optionsSpecified,
      touchEnabled: 'ontouchstart' in window
      
      # string or function (???)
      dragClass: 'ds-drag'
      sortOpts: {}
      dragOpts:
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
      
      @
  
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
DropSort::getPos = (elem) ->
  {
    bottom: @getStyle elem, 'bottom'
    right: @getStyle elem, 'right'
    left: @getStyle elem, 'left'
    top: @getStyle elem, 'top'
  }
  
# something something _.uniqueId
DropSort::bindings = {}
  
###
 add / remove classes: http://stackoverflow.com/questions/2155737/remove-css-class-from-element-with-javascript-no-jquery
 possibly use the ClassList solution.
###


# Export it to the appropriate place
root = exports ? @
root.DropSort = DropSort