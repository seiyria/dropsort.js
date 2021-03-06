
class DOMHelper
  
  # get the matching function for the current browser
  # if none exists then this won't work
  @setMatchesFunction = (el) ->
    el.matches = 
      el.matches or 
      el.matchesSelector or
      el.webkitMatchesSelector or
      el.mozMatchesSelector or 
      el.oMatchesSelector or
      el.msMatchesSelector
    
  # clone an element
  @clone = (element) ->
    clone = element.cloneNode true
    element.parentNode.insertBefore clone, element
    @movePositionProperties element, clone

  # set up the positional properties between an element and another element
  # handles top, left, and position='absolute'
  @movePositionProperties = (baseElement, toElement) ->
    box = @getBoundingBoxFor baseElement
    parentBox = @getBoundingBoxFor toElement.parentNode
    baseElement.style.left = toElement.style.left = "#{box.offsetX-parentBox.offsetX}px"
    baseElement.style.top = toElement.style.top = "#{box.offsetY-parentBox.offsetY}px"
    baseElement.style.position = toElement.style.position = 'absolute'
    toElement
    
  # Get the bounding box for an element
  @getBoundingBoxFor = (elem) ->
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
    
  # stop an event by whatever means it has available
  @stopEvent = (event) ->
    event.preventDefault() if event.preventDefault
    event.stopPropagation() if event.stopPropagation
    event.returnvalue = false

  # get the current target of the element
  @getEventTarget = (event) ->
    target = event.target
    target = event.srcElement if event.srcElement
    target = target.parentNode if target.nodeType is 3
    
    target
    
  # Get a style property from an element
  @getStyle = (elem, prop) ->
    return elem.currentStyle[prop] if elem.currentStyle
    return window.getComputedStyle(elem).getPropertyValue prop if window.getComputedStyle
    return elem.style[prop] if elem.style
    
  # Get the window size 
  @getWindowSize = ->
    de = document.documentElement
    body = document.getElementsByTagName('body')[0]
    {
      x: window.innerWidth or de.clientWidth or body.clientWidth
      y: window.innerHeight or de.clientHeight or body.clientHeight
    }
  
  # check if el has className
  @hasClass = (el, className) ->
    (@getClasses(el).indexOf className) isnt -1
    
  # Get all classes for el
  @getClasses = (el) ->
    el.className
  
  # add a class to an element
  @addClass = (el, newClass) ->
    if el.classList
      el.classList.add newClass
    else
      el.className += " #{newClass}"
    
  # remove a class from an element
  @removeClass = (el, oldClass) ->
    if el.classList
      el.classList.remove oldClass
    else
      el.className = el.className.replace new RegExp('(^|\\b)' + oldClass.split(' ').join('|') + '(\\b|$)', 'gi'), ' '
      
class DOMSpatialHelper

  # check which half of the item is covered
  # this is used to determine which way to go between a horizontal and vertical list
  @getHoveredItemHalf = (hoveredNode, event, orientation = "vertical") ->
    compare = 
      if orientation is "vertical" then coord: 'offsetY', width: 'offsetHeight' 
      else coord: 'offsetX', width: 'offsetWidth'

    box = DOMHelper.getBoundingBoxFor hoveredNode
    isAtLeft = box[compare.coord] <= event.x <= box[compare.coord]+box[compare.width]
    
    funcCall = if (@isLastElement hoveredNode) and (not isAtLeft) then "appendChild" else "insertBefore"
    insertArg = 
      if isAtLeft or @isFirstElement hoveredNode then hoveredNode 
      else hoveredNode.nextSibling
      
    [funcCall, insertArg]
    
  # check if this is the first child in the parents children
  @isFirstElement = (node) ->
    (Array.prototype.indexOf.call node.parentNode.children, node) is 0
    
  # check if this is the last child in the parents children
  @isLastElement = (node) ->
    (Array.prototype.indexOf.call node.parentNode.children, node) is node.parentNode.children.length-1

class MathHelper

  # Check it num is divisible by divisor
  @divisibleBy = (num, divisor = 1) ->
    num % divisor is 0
    
  # TODO convert to coffee
  @pointInPolygon = `function (point, vs) {
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
  
root = exports ? @
root.DOMHelper = DOMHelper
root.DOMSpatialHelper = DOMSpatialHelper
root.MathHelper = MathHelper