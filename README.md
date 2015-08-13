html-docx-js
============

This is a very small library that is capable of converting HTML documents to DOCX format that
is used by Microsoft Word 2007 and onward. It manages to perform the conversion in the browser by
using a feature called 'altchunks'. In a nutshell, it allows embedding content in a different markup
language. We are using MHT document to ship the embedded content to Word as it allows to handle images.
After Word opens such file, it converts the external content to Word Processing ML (this
is how the markup language of DOCX files is called) and replaces the reference.

Altchunks were not supported by Microsoft Word for Mac 2008 and are not supported by LibreOffice and
Google Docs.

Compatibility
-------------

This library should work on any modern browser that supports `Blobs` (either natively or via
[Blob.js](https://github.com/eligrey/Blob.js/)). It was tested on Google Chrome 36, Safari 7 and
Internet Explorer 10.

It also works on Node.js (tested on v0.10.12) using `Buffer` instead of `Blob`.

Images Support
-------------

This library supports only inlined base64 images (sourced via DATA URI). But it is easy to convert a
regular image (sourced from static folder) on the fly. If you need an example of such conversion you can [checkout a demo page source](https://github.com/evidenceprime/html-docx-js/blob/master/test/sample.html) (see function `convertImagesToBase64`).

Usage and demo
--------------

Very minimal demo is available as `test/sample.html` in the repository and
[online](http://evidenceprime.github.io/html-docx-js/test/sample.html). Please note that saving
files on Safari is a little bit convoluted and the only reliable method seems to be falling back
to a Flash-based approach (such as [Downloadify](https://github.com/dcneiner/Downloadify)).
Our demo does not include this workaround to keep things simple, so it will not work on Safari at
this point of time.

You can also find a sample for using it in Node.js environment
[here](https://github.com/evidenceprime/html-docx-js-node-sample).

To generate DOCX, simply pass a HTML document (as string) to `asBlob` method to receive `Blob` (or `Buffer`)
containing the output file.

    var converted = htmlDocx.asBlob(content);
    saveAs(converted, 'test.docx');

`asBlob` can take additional options for controlling page setup for the document:

* `orientation`: `landscape` or `portrait` (default)
* `margins`: map of margin sizes (expressed in twentieths of point, see
  [WordprocessingML documentation](http://officeopenxml.com/WPsectionPgMar.php) for details):
    - `top`: number (default: 1440, i.e. 2.54 cm)
    - `right`: number (default: 1440)
    - `bottom`: number (default: 1440)
    - `left`: number (default: 1440)
    - `header`: number (default: 720)
    - `footer`: number (default: 720)
    - `gutter`: number (default: 0)

For example:

    var converted = htmlDocx.asBlob(content, {orientation: 'landscape', margins: {top: 720}});
    saveAs(converted, 'test.docx');

**IMPORTANT**: please pass a complete, valid HTML (including DOCTYPE, `html` and `body` tags).
This may be less convenient, but gives you possibility of including CSS rules in `style` tags.

`html-docx-js` is distributed as 'standalone' Browserify module (UMD). You can `require` it as
`html-docx`. If no module loader is available, it will register itself as `window.htmlDocx`.
See `test/sample.html` for details.

License
-------

Copyright (c) 2015 Evidence Prime, Inc.
See the LICENSE file for license rights and limitations (MIT).
