// Generated by CoffeeScript 1.6.2
(function() {
  $(function() {
    $('body').on('dragover', function(e) {
      e.preventDefault();
      return e.stopPropagation();
    });
    return $('body').on('drop', function(e) {
      var f, files, reader, _i, _len, _results;

      e.preventDefault();
      e.stopPropagation();
      console.log(files = e.originalEvent.dataTransfer.files);
      _results = [];
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        f = files[_i];
        console.log("Loading file " + f.name + "...");
        reader = new FileReader();
        reader.onload = function() {
          console.log(reader.result);
          return $.post('/new', {
            data: reader.result
          }, function(r) {
            return window.location.href = "/" + r;
          });
        };
        _results.push(reader.readAsText(f));
      }
      return _results;
    });
  });

}).call(this);

/*
//@ sourceMappingURL=index.map
*/
