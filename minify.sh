#!/bin/bash
# Minificar los js
export APPDIR=$(pwd)
cd $APPDIR/interfaz/public
cat js/jquery.min.js js/bootstrap.min.js js/jquery.colorbox-min.js \
 js/underscore-min.js js/backbone.js js/jquery.cookie.min.js js/chosen.jquery.js \
 js/moment.min.js js/moment.es.js js/jquery-datepicker.min.js js/misScripts.js \
  | uglifyjs --reserved-names "require,$super" -o js/app.min.js
cd $APPDIR