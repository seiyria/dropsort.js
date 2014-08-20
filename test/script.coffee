nodes = document.querySelectorAll ".dragme-contained"
_.each nodes, (node) ->
  x = new DropSort node, dragContainerType: 'parent'

node = document.getElementById "dm3"
x = new DropSort node, dragAnchorElements: ".gets-dragged", handle: "handle"

node = document.getElementById "dm2"
x = new DropSort node

node = document.getElementById "dropMe"
x = new DropSort node, doDrop: yes

#x = new DropSort document.getElementById 'dragMeAlso'

sortClickHandler = (sortable, element, event) ->
  [ctrl, shift] = [event.ctrlKey, event.shiftKey]
  
  if (not ctrl) and (not shift)
    state = element._isSortSelected
    sortable.unselectAll()
    element[if state then 'unselect' else 'select']()

  else if shift and sortable._lastSelected > -1 and sortable._dropSorts[sortable._lastSelected]._isSortSelected
    elIndex = sortable._dropSorts.indexOf element
    
    sortable.selectRange sortable._lastSelected, elIndex if sortable._lastSelected < elIndex
    sortable.selectRange elIndex, sortable._lastSelected if sortable._lastSelected > elIndex
    
  else if ctrl and (not shift)
    element.toggle()
    
    sortable.selectRange sortable._lastSelected, elIndex if sortable._lastSelected < elIndex
    sortable.selectRange elIndex, sortable._lastSelected if sortable._lastSelected > elIndex
    
  sortable._lastSelected = sortable._dropSorts.indexOf element

# returning undefined will not trigger the console error
# that normally lets you know if your element is not a valid
# helper for dragging
countingDOMHelper = ->
  el = document.createElement "li"
  numberSelected = @countSelected()
  el.innerText = "#{numberSelected} items selected"
  if numberSelected > 1 then el
  
dropCallback = ->
  _.each @_sortable.getSelected(), (dropSort) ->
    dropSort.restoreDisplay()
    
  @_sortable.unselectAll()
  
dragCallback = ->
  _.each @_sortable.getSelected(), (dropSort) ->
    dropSort.storeDisplay()
    dropSort.hideDisplay()
  
nodes = document.querySelectorAll ".sortable"
_.each nodes, (node) ->
  x = new DropSort node, 
    doSort: yes
    sortElementClick: sortClickHandler
    sortDragPlaceholder: countingDOMHelper
    dragUpCallback: dropCallback
    dragStartCallback: dragCallback