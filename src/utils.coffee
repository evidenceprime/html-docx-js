mhtDocumentTemplate = require './templates/mht_document'
mhtPartTemplate = require './templates/mht_part'

module.exports =
  getMHTdocument: (htmlSource) ->
    # take care of images
    {htmlSource, imageContentParts} = @_prepareImageParts htmlSource
    # for proper MHT parsing all '=' signs in html need to be replaced with '=3D'
    htmlSource = htmlSource.replace /\=/g, '=3D'
    mhtDocumentTemplate {htmlSource, contentParts: imageContentParts.join '\n'}

  _prepareImageParts: (htmlSource) ->
    imageContentParts = []
    inlinedSrcPattern = /"data:(\w+\/\w+);(\w+),(\S+)"/g
    # replacer function for images sources via DATA URI
    inlinedReplacer = (match, contentType, contentEncoding, encodedContent) ->
      index = imageContentParts.length
      extension = contentType.split('/')[1]
      contentLocation = "file:///C:/fake/image#{index}.#{extension}"
      imageContentParts.push mhtPartTemplate {contentType, contentEncoding, contentLocation, encodedContent}
      "\"#{contentLocation}\""

    if typeof htmlSource is 'string'
      return {htmlSource, imageContentParts} unless /<img/g.test htmlSource

      htmlSource = htmlSource.replace inlinedSrcPattern, inlinedReplacer
      {htmlSource, imageContentParts}
    else
      throw new Error "Not a valid source provided!"
