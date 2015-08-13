JSZip = require 'jszip'
internal = require './internal'
fs = require 'fs'

module.exports =
  asBlob: (html, options) ->
    zip = new JSZip()
    internal.addFiles(zip, html, options)
    internal.generateDocument(zip)
