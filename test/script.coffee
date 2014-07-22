nodes = document.querySelectorAll ".dragme-contained"
_.each nodes, (node) ->
  x = new DropSort node, dragContainerType: 'parent'
  
nodes = document.querySelectorAll ".dragme"
_.each nodes, (node) ->
  x = new DropSort node, dragAnchorElements: ".gets-dragged"

#x = new DropSort document.getElementById 'dragMeAlso'