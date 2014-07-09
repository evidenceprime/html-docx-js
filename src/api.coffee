JSZip = require 'jszip'
internal = require './internal'
fs = require 'fs'

module.exports =
  asBlob: (html) ->
    zip = new JSZip()
    internal.addFiles(zip, html)
    internal.generateDocument(zip)
