fs = require 'fs'
W = require 'when'
documentTemplate = require './templates/document'
mhtDocumentTemplate = require './templates/mht_document'
mhtPartTemplate = require './templates/mht_part'
_ =
  merge: require 'lodash.merge'
  forEach: (arrayLikeObject, iteratee) ->
    [].forEach.call arrayLikeObject, iteratee

module.exports =
  generateDocument: (zip) ->
    buffer = zip.generate(type: 'arraybuffer')
    if global.Blob
      new Blob [buffer],
        type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    else if global.Buffer
      new Buffer new Uint8Array(buffer)
    else
      throw new Error "Neither Blob nor Buffer are accessible in this environment. " +
        "Consider adding Blob.js shim"

  generateMHTDocument: (htmlSource) ->
    # take care of images
    @prepareImageParts(htmlSource).then (result) ->
      if result.htmlSource
        {htmlSource, imageContentParts} = result
      else
        htmlSource = htmlSource.outerHTML
        imageContentParts = result.imageContentParts
      # for proper MHT parsing all '=' signs in html tags need to be replaced with '=3D'
      htmlSource = htmlSource.replace /\=/g, '=3D'
      W.resolve mhtDocumentTemplate {htmlSource, contentParts: imageContentParts.join '\n'}
    , (err) -> throw err

  prepareImageParts: (htmlSource) ->
    imageContentParts = []
    # regular expressions to work with DATA URI sourced (inlined) and regular images
    inlinedSrcPattern = /"data:(\w+\/\w+);(\w+),(\S+)"/g
    regularSrcPattern = /(<img[^<>]+src=")(?!file)(?!data\:\S+)(\S+)(")/g
    # replacer function for images sources via DATA URI
    inlinedReplacer = (match, contentType, contentEncoding, encodedContent) ->
      index = imageContentParts.length
      extension = contentType.split('/')[1]
      contentLocation = "file://fake/image#{index}.#{extension}"
      imageContentParts.push mhtPartTemplate {contentType, contentEncoding, contentLocation, encodedContent}
      "\"#{contentLocation}\""

    if typeof htmlSource is 'string'
      # don't have to do anything if there are no images in provided htmlSource
      return W.resolve({htmlSource, imageContentParts}) unless /<img/g.test htmlSource
      # take care of 'regular' images first
      matches = htmlSource.match regularSrcPattern
      if matches
        deferred = W.defer()
        # temporary canvas and image objects needed to convert image into base64 string
        canvas = document.createElement 'canvas'
        fakeImg = document.createElement 'img'
        fakeImg.style.visibility = 'hidden'
        document.body.appendChild fakeImg
        # fn to supply trigger canvas drawing by changing the fakeImg src
        matchRunner = ->
          matchString = matches.shift()
          imgSrc = matchString.match(/src="(\S+)"/)[1]
          fakeImg.src = imgSrc
        # fakeImg onload callback will generate base64 data string
        fakeImg.onload = ->
          # prepare to draw on canvas
          ctx = canvas.getContext '2d'
          ctx.clearRect 0, 0, canvas.width, canvas.height
          # adopt canvas to image size and draw
          [canvas.width, canvas.height] = [@width, @height]
          ctx.drawImage this, 0, 0
          imageDataURI = canvas.toDataURL()
          htmlSource = htmlSource.replace @src, imageDataURI
          # if this was the last regular image we can clean-up and proceed to inlined images
          if matches.length is 0
            fakeImg.remove()
            canvas = null
            htmlSource = htmlSource.replace inlinedSrcPattern, inlinedReplacer
            deferred.resolve {htmlSource, imageContentParts}
          else
            matchRunner()
        # initiate first replacement and provide promise
        matchRunner()
        deferred.promise
      else
        htmlSource = htmlSource.replace inlinedSrcPattern, inlinedReplacer
        W.resolve {htmlSource, imageContentParts}
    else if htmlSource.nodeName
      W.reject new Error 'Processing DOM objects is not implemented'
    else
      W.reject new Error "No valid source provided!"

  _convertImgToDataURL: (image, canvas) ->
    ctx = canvas.getContext '2d'
    ctx.clearRect 0, 0, canvas.width, canvas.height
    [canvas.width, canvas.height] = [image.width, image.height]
    ctx.drawImage image, 0, 0
    canvas.toDataURL()

  renderDocumentFile: (documentOptions = {}) ->
    templateData = _.merge margins:
      top: 1440
      right: 1440
      bottom: 1440
      left: 1440
      header: 720
      footer: 720
      gutter: 0
    ,
      switch documentOptions.orientation
        when 'landscape' then height: 12240, width: 15840, orient: 'landscape'
        else width: 12240, height: 15840, orient: 'portrait'
    ,
      margins: documentOptions.margins

    documentTemplate(templateData)

  addFiles: (zip, htmlSource, documentOptions) ->
    zip.file '[Content_Types].xml', fs.readFileSync __dirname + '/assets/content_types.xml'
    zip.folder('_rels').file '.rels', fs.readFileSync __dirname + '/assets/rels.xml'

    @generateMHTDocument(htmlSource).then (mhtDoc) =>
      zip.folder 'word'
        .file 'document.xml', @renderDocumentFile documentOptions
        .file 'afchunk.mht', mhtDoc
        .folder '_rels'
          .file 'document.xml.rels', fs.readFileSync __dirname + '/assets/document.xml.rels'
    , (err) -> throw err
