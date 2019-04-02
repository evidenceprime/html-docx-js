var _, documentTemplate, fs, utils;

fs = require('fs');

documentTemplate = require('./templates/document');

utils = require('./utils');

_ = {
  merge: require('lodash.merge')
};

module.exports = {
  generateDocument: function(zip) {
    var buffer;
    buffer = zip.generate({
      type: 'arraybuffer'
    });
    if (global.Blob) {
      return new Blob([buffer], {
        type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      });
    } else if (global.Buffer) {
      return new Buffer(new Uint8Array(buffer));
    } else {
      throw new Error("Neither Blob nor Buffer are accessible in this environment. " + "Consider adding Blob.js shim");
    }
  },
  renderDocumentFile: function(documentOptions) {
    var templateData;
    if (documentOptions == null) {
      documentOptions = {};
    }
    templateData = _.merge({
      margins: {
        top: 1440,
        right: 1440,
        bottom: 1440,
        left: 1440,
        header: 720,
        footer: 720,
        gutter: 0
      }
    }, (function() {
      switch (documentOptions.orientation) {
        case 'landscape':
          return {
            height: 12240,
            width: 15840,
            orient: 'landscape'
          };
        default:
          return {
            width: 12240,
            height: 15840,
            orient: 'portrait'
          };
      }
    })(), {
      margins: documentOptions.margins
    });
    return documentTemplate(templateData);
  },
  addFiles: function(zip, htmlSource, documentOptions) {
    zip.file('[Content_Types].xml', fs.readFileSync(__dirname + '/assets/content_types.xml'));
    zip.folder('_rels').file('.rels', fs.readFileSync(__dirname + '/assets/rels.xml'));
    return zip.folder('word').file('document.xml', this.renderDocumentFile(documentOptions)).file('afchunk.mht', utils.getMHTdocument(htmlSource)).folder('_rels').file('document.xml.rels', fs.readFileSync(__dirname + '/assets/document.xml.rels'));
  }
};
