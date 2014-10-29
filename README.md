dropsort.js
===========
A drag/drop/sortable replacement to jQuery UI.

Progress Plunk
==============
This plunk will be continuously updated while testing new features: http://plnkr.co/edit/vDHEzoEZwmkIGtKh91DR?p=preview
Feel free to discuss any aspect of the plunk in an issue.

Goals
=====
* support touch and mouse drags simulateously (some devices have both a mouse and touch screen)
* all calls should be chainable (where applicable)
* be easily extensible and pluggable into environments like jQuery, AngularJS, and knockout.js
* support drag, drop, and sortable controls
* draggable controls should be able to auto-expand in the dragged direction, and containers should be flexible, ie, if I have solid bounds on top, left, and right, but nothing specified for the bottom, the container should expand downwards
* sortable controls should be able to drag / drop multiple items natively (ie, not with 100 lines of code wrapping jQuery UI events). selection methods may or may not be baked in.
* use lodash where possible to reduce code clutter - in combination with coffeescript, the code base should be clean.
* unit tested where possible
* coffeelint / jshint to an acceptable standard
* support amd / require / bower / etc
* support all modern browers - chrome / firefox / IE9+
* Works in scrollable modal boxes like fancybox (so can't have position calculations tied totally to the window, has to be aware of a box that it's in and scroll the box if the element gets near the top/bottom/sides)
* be compatible with HTML5 drag & drop ???
* the draggable objects should stay in sync with the mouse cursor where possible. when moving out of bounds and then back in, the item should be at the edge of the mouse pointer, not hundreds of pixels away
