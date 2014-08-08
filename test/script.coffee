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

nodes = document.querySelectorAll ".sortable"
_.each nodes, (node) ->
  x = new DropSort node, doSort: yes