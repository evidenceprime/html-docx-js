var JSZip, fs, internal;

JSZip = require('jszip');

internal = require('./internal');

fs = require('fs');

module.exports = {
  asBlob: function(html, options) {
    var zip;
    zip = new JSZip();
    internal.addFiles(zip, html, options);
    return internal.generateDocument(zip);
  }
};
