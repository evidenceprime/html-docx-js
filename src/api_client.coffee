JSZip = require 'jszip'
internal = require './internal'
cssInliner = require './utils/cssInliner'

module.exports =
  asBlob: (html, options) ->
    zip = new JSZip()
    internal.addFiles(zip, cssInliner(html), options)
    internal.generateDocument(zip)
