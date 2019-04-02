var cssInliner, mhtDocumentTemplate, mhtPartTemplate;

mhtDocumentTemplate = require('./templates/mht_document');

mhtPartTemplate = require('./templates/mht_part');

cssInliner = require('juice');

module.exports = {
  getMHTdocument: function(htmlSource) {
    var imageContentParts, ref;
    ref = this._prepareImageParts(htmlSource), htmlSource = ref.htmlSource, imageContentParts = ref.imageContentParts;
    htmlSource = cssInliner(htmlSource, {
      preserveMediaQueries: true,
      preserveFontFaces: true
    }).replace(/\=/g, '=3D');
    return mhtDocumentTemplate({
      htmlSource: htmlSource,
      contentParts: imageContentParts.join('\n')
    });
  },
  _prepareImageParts: function(htmlSource) {
    var imageContentParts, inlinedReplacer, inlinedSrcPattern;
    imageContentParts = [];
    inlinedSrcPattern = /"data:(\w+\/\w+);(\w+),(\S+)"/g;
    inlinedReplacer = function(match, contentType, contentEncoding, encodedContent) {
      var contentLocation, extension, index;
      index = imageContentParts.length;
      extension = contentType.split('/')[1];
      contentLocation = "file:///C:/fake/image" + index + "." + extension;
      imageContentParts.push(mhtPartTemplate({
        contentType: contentType,
        contentEncoding: contentEncoding,
        contentLocation: contentLocation,
        encodedContent: encodedContent
      }));
      return "\"" + contentLocation + "\"";
    };
    if (typeof htmlSource === 'string') {
      if (!/<img/g.test(htmlSource)) {
        return {
          htmlSource: htmlSource,
          imageContentParts: imageContentParts
        };
      }
      htmlSource = htmlSource.replace(inlinedSrcPattern, inlinedReplacer);
      return {
        htmlSource: htmlSource,
        imageContentParts: imageContentParts
      };
    } else {
      throw new Error("Not a valid source provided!");
    }
  }
};
