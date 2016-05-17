JSZip = require 'jszip'
internal = require './internal'
juice = require 'juice'

module.exports =
  asBlob: (html, options) ->
    zip = new JSZip()
    internal.addFiles(zip, juice(html), options)
    internal.generateDocument(zip)
