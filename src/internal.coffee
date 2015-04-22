fs = require 'fs'
documentTemplate = require './templates/document'
_ = assign: require 'lodash.assign'

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

  renderDocumentFile: (documentOptions = {}) ->
    templateData = _.assign {},
      switch documentOptions.orientation
        when 'landscape' then height: 12240, width: 15840, orient: 'landscape'
        else width: 12240, height: 15840, orient: 'portrait'

    documentTemplate(templateData)

  addFiles: (zip, htmlSource, documentOptions) ->
    zip.file '[Content_Types].xml', fs.readFileSync __dirname + '/assets/content_types.xml'
    zip.folder('_rels').file '.rels', fs.readFileSync __dirname + '/assets/rels.xml'
    zip.folder 'word'
      .file 'document.xml', @renderDocumentFile documentOptions
      .file 'afchunk.htm', htmlSource
      .folder '_rels'
        .file 'document.xml.rels', fs.readFileSync __dirname + '/assets/document.xml.rels'
