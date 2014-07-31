html-docx-js
============

This is a very small library that is capable of converting HTML documents to DOCX format that
is used by Microsoft Word 2007 and onward. It manages to perform the conversion in the browser by
using a feature called 'altchunks'. In a nutshell, it allows embedding content in a different markup
language. After Word opens such file, it converts the external content to Word Processing ML (this
is how the markup language of DOCX files is called) and replaces the reference.

Altchunks were not supported by Microsoft Word for Mac 2008 and are not supported by LibreOffice.

Compatibility
-------------

This library should work on any modern browser that supports `Blobs` (either natively or via 
[Blob.js](https://github.com/eligrey/Blob.js/)). It was tested on Google Chrome 36, Safari 7 and
Internet Explorer 10.

It also works on Node.js (tested on v0.10.12) using `Buffer` instead of `Blob`.

Usage and demo
--------------

Very minimal demo is available as `test/sample.html` in the repository and 
[online](http://evidenceprime.github.io/html-docx-js/test/sample.html). Please note that saving
files on Safari is a little bit convoluted and the only reliable method seems to be falling back
to a Flash-based approach (such as [Downloadify](https://github.com/dcneiner/Downloadify)).
Our demo does not include this workaround to keep things simple, so it will not work on Safari at
this point of time.

To generate DOCX, simply pass a HTML document to `asBlob` method to receive `Blob` (or `Buffer`)
containing the output file.

    var converted = htmlDocx.asBlob(content);
    saveAs(converted, 'test.docx');

**IMPORTANT**: please pass a complete, valid HTML (including DOCTYPE, `html` and `body` tags).
This may be less convenient, but gives you possibility of including CSS rules in `style` tags.

`html-docx-js` is distributed as 'standalone' Browserify module (UMD). You can `require` it as
`html-docx`. If no module loader is available, it will register itself as `window.htmlDocx`.
See `test/sample.html` for details.

License
-------

Copyright (c) 2014 Evidence Prime, Inc.
See the LICENSE file for license rights and limitations (MIT).
