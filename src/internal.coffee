fs = require 'fs'

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

  addFiles: (zip, htmlSource) ->
    zip.file '[Content_Types].xml', fs.readFileSync __dirname + '/assets/content_types.xml'
    zip.folder('_rels').file '.rels', fs.readFileSync __dirname + '/assets/rels.xml'
    zip.folder 'word'
      .file 'document.xml', fs.readFileSync __dirname + '/assets/document.xml'
      .file 'afchunk.htm', htmlSource
      .folder '_rels'
        .file 'document.xml.rels', fs.readFileSync __dirname + '/assets/document.xml.rels'
