dropsort.js
===========

A drag/drop/sortable replacement to jQuery UI

Goals
=====
* support touch and mouse drags
* all calls should be chainable
* be easily extensible and pluggable into environments like jQuery, AngularJS, and knockout.js
* support drag, drop, and sortable controls
* draggable controls should be able to auto-expand in the dragged direction, and containers should be flexible, ie, if I have solid bounds on top, left, and right, but nothing specified for the bottom, the container should expand downwards
* sortable controls should be able to drag / drop multiple items natively (ie, not with 100 lines of code wrapping jQuery UI events). selection methods may or may not be baked in.
* use lodash where possible to reduce code clutter - in combination with coffeescript, the code base should be clean.
* unit tested where possible
* coffeelint / jshint to an acceptable standard
* support amd / require / bower / etc
