JSZip = require 'jszip'
internal = require './internal'
fs = require 'fs'

module.exports =
  asBlob: (html, options) ->
    zip = new JSZip()
    internal.addFiles(zip, html, options)
    .then (zip) -> internal.generateDocument(zip)
    .catch (err) -> throw err
