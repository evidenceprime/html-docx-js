chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
chai.use require 'sinon-chai'
internal = require '../build/internal'
utils = require '../build/utils'
CSSInliner = require '../build/css_inliner'

describe 'Adding files', ->
  beforeEach ->
    @data = {}
    zip = (data) ->
      entry =
        file: (name, content) ->
          data[name] = content
          entry
        folder: (name) ->
          data[name] = {}
          zip data[name]
    sinon.stub(internal, 'renderDocumentFile').returns '<document />'
    internal.addFiles zip(@data), 'foobar', someOption: true
  afterEach ->
    internal.renderDocumentFile.restore()

  it 'should add file for embedded content types', ->
    expect(@data['[Content_Types].xml']).to.be.defined
    content = String(@data['[Content_Types].xml'])
    expect(content).to.match /PartName="\/word\/afchunk.mht"/
    expect(content).to.match /PartName="\/word\/document.xml"/
    expect(content).to.match /Extension="rels"/

  it 'should add manifest for Word document', ->
    expect(@data._rels['.rels']).to.be.defined
    content = String(@data._rels['.rels'])
    expect(content).to.match /Target="\/word\/document.xml"/

  it 'should add MHT file with given content', ->
    expect(@data.word['afchunk.mht']).to.be.defined
    expect(String @data.word['afchunk.mht']).to.match /foobar/

  it 'should render the Word document and add its contents', ->
    expect(internal.renderDocumentFile).to.have.been.calledWith someOption: true
    expect(@data.word['document.xml']).to.be.defined
    expect(String @data.word['document.xml']).to.match /<document \/>/

  it 'should add relationship file to link between Word and HTML files', ->
    expect(@data.word._rels['document.xml.rels']).to.be.defined
    expect(String @data.word._rels['document.xml.rels']).to
      .match /Target="\/word\/afchunk.mht" Id="htmlChunk"/

describe 'Coverting HTML to MHT', ->
  it 'should convert HTML source to an MHT document', ->
    htmlSource = '<!DOCTYPE HTML><head></head><body></body>'
    expect(utils.getMHTdocument(htmlSource)).to.match
    /^MIME-Version: 1.0\nContent-Type: multipart\/related;/

  it 'should fail if HTML source is not a string', ->
    htmlSource = {}
    expect(utils._prepareImageParts.bind(null, htmlSource)).to.throw /Not a valid source provided!/

  it 'should detect any embedded image and change its source to ContentPart name', ->
    htmlSource = '<p><img src="data:image/jpeg;base64,PHN2ZyB..."></p>'
    expect(utils.getMHTdocument(htmlSource)).to.match /<img src=3D"file:\/\/fake\/image0.jpeg">/

  it 'should produce ContentPart for each embedded image', ->
    htmlSource = '<p><img src="data:image/jpeg;base64,PHN2ZyB...">
    <img src="data:image/png;base64,PHN2ZyB...">
    <img src="data:image/gif;base64,PHN2ZyB..."></p>'
    imageParts = utils._prepareImageParts(htmlSource).imageContentParts
    expect(imageParts).to.have.length 3
    imageParts.forEach (image, index) ->
      expect(image).to.match /Content-Type: image\/(jpeg|png|gif)/
      expect(image).to.match /Content-Transfer-Encoding: base64/
      expect(image).to.have.string "Content-Location: file://fake/image#{index}."

  it 'should replace = signs to 3D=', ->
    htmlSource = '<body style="width: 100%">This = 0</body>'
    expect(utils.getMHTdocument(htmlSource)).to.match
    '<body style=3D"width: 100%">This 3D= 0</body>'

describe 'Inlining CSS', ->
  it 'shouldn\'t fail if input html is not a valid HTML document or if it doesn\'t have styles', ->
    htmlSourceNotValid = '<div></div>'
    htmlSourceNoStyles = '<html><head><styles></styles></head><body></body></html>'
    expect(CSSInliner.getInlinedHTML(htmlSourceNotValid)).to.be.equal htmlSourceNotValid
    expect(CSSInliner.getInlinedHTML(htmlSourceNoStyles)).to.be.equal htmlSourceNoStyles

  it 'should correctly parse HTML containing different kind of tags', ->
    htmlSource = '<body><div><p>Test<input></p><br></div><div><img></div><script></script></body>'
    CSSInliner.getInlinedHTML(htmlSource)
    expect(CSSInliner._nodeCounter).to.be.equal 6

  it 'should correctly build node object and register it', ->
    htmlSource =
    '<body>
      <br>
      <div></div>
      <div>
        <input>
        <div id="id1" class="test test2" contenteditable="true" ></div>
      </div>
    </body>'
    CSSInliner.getInlinedHTML(htmlSource)

    expect(CSSInliner.nodes[1].tag).to.be.equal = 'div'
    expect(CSSInliner.tag).to.include.keys 'div'
    expect(CSSInliner.tag).to.include.keys 'input'
    expect(CSSInliner.nodes[5].path).to.eql [1, 3]
    expect(CSSInliner.nodes[5].classList).to.eql ['test', 'test2']
    expect(CSSInliner.class).to.include.keys 'test2'
    expect(CSSInliner.nodes[5].id).to.be.equal 'id1'
    expect(CSSInliner.id).to.include.keys 'id1'
    expect(CSSInliner.nodes[5].attr).to.eql [name: 'contenteditable', value: "\"true\""]
    expect(CSSInliner.attr).to.include.keys 'contenteditable'
    expect(CSSInliner.attr.contenteditable).to.eql "\"true\"": [5], "_all": [5]

  it 'should correctly parse CSS styles', ->
    htmlSource =
    '<style>
      div {
        color: red;
      }
      table, div {margin: 100px;}
      #id1 {
        font-weight: bold;
        padding: 0;
      }
      .test {
        margin: 10px;
      }
      .test.test2 {
        border: none;
      }
      [contenteditable] {
        cursor: pointer
      }
    </style>'
    CSSInliner.getInlinedHTML(htmlSource)
    expect(Object.keys(CSSInliner.stylesObj)).to.be.have.length 6
    expect(CSSInliner.stylesObj['div']).to.eql
     declarations: color: 'red', margin: '100px'
     specificity: 1
    expect(CSSInliner.stylesObj['#id1']).to.eql
     declarations: 'font-weight': 'bold', padding: '0'
     specificity: 100
    expect(CSSInliner.stylesObj['.test.test2'].specificity).to.be.equal 20

  it 'should correctly determine selector type', ->
    spy = sinon.spy(CSSInliner, '_getSelectorType')
    CSSInliner.getNodesIdsByCSSSelector('.test.test2')
    expect(spy.returned('class')).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('[contenteditable]')
    expect(spy.returned('attr')).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('#id1')
    expect(spy.returned('id')).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('div.some-class')
    expect(spy.returned('tagWithClass')).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('div')
    expect(spy.returned('tag')).to.be.true

  it 'should correctly lookup with (multi-)class selector', ->
    htmlSource =
    '<body><div class="first">
      <div></div>
      <br>
      <p><span></span></p>
      <div class="first second"></div>
      <div class="third">
        <p class="first third"></p>
      </div>
      <div class="first second"></div>
    </div></body>'
    CSSInliner.getInlinedHTML(htmlSource)
    spy = sinon.spy(CSSInliner, 'getNodesIdsByCSSSelector')
    CSSInliner.getNodesIdsByCSSSelector('.first.second')
    expect(spy.returned([6, 9])).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('.first.third')
    expect(spy.returned([8])).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('.first')
    expect(spy.returned([2, 6, 8, 9])).to.be.true

  it 'should correctly lookup in deep DOM trees with complex CSS selectors', ->
    htmlSource =
    '<body>
      <div class="l1"></div>
      <div class="l1">
        <div class="l2" contenteditable="false" readonly>
          <p></p>
          <input>
        </div>
        <div id="id1" class="l2">
          <div class="l3">
            <div class="l4">
              <input>
              <input disabled>
            </div>
          </div>
        </div>
      </div>
    </body>'
    CSSInliner.getInlinedHTML(htmlSource)
    CSSInliner.getNodesIdsByCSSSelector('.l1 [contenteditable="false"] p')
    expect(CSSInliner.getNodesIdsByCSSSelector.returned([5])).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('div[contenteditable]')
    expect(CSSInliner.getNodesIdsByCSSSelector.returned([4])).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('.l1 .l2 input')
    expect(CSSInliner.getNodesIdsByCSSSelector.returned([6, 10, 11])).to.be.true
    CSSInliner.getNodesIdsByCSSSelector('#id1 .l3 .l4 input[disabled]')
    expect(CSSInliner.getNodesIdsByCSSSelector.returned([11])).to.be.true

  it 'should inline styles and produce resulting HTML string', ->
    htmlSource =
    '<style>
      .l1 {
        margin: 0;
        border: 1px solid red;
      }
      .l2 {
        color: blue;
        font: Arial;
      }
      input {
        width: 100px;
      }
      input[disabled] {
        width: 10px;
        line-height: 24px;
      }
      #div4 .l3 .l4 input[disabled] {
        background-color: black;
      }
      .l1 [contenteditable="false"] p {
        color: navy;
      }
      .l1.small {
        color: red;
      }
    </style>
    <body>
      <div id="div1" class="l1"></div>
      <div id="div2" class="l1">
        <div id="div3" class="l2" contenteditable="false" readonly>
          <p id="p1"></p>
          <input id="input1">
        </div>
        <div id="div4" class="l2">
          <div id="div5" class="l3">
            <div id="div6" class="l4">
              <input id="input2">
              <input id="input3" disabled>
            </div>
          </div>
        </div>
      </div>
      <div id="div7" class="l1 small" style="font-weight: bold;"></div>
    </body>'
    inlinedHTML = CSSInliner.getInlinedHTML(htmlSource)
    expect(inlinedHTML).to.be.length.above 0
    expect(inlinedHTML).to.have.string '<div id="div7" class="l1 small" style="font-weight:
      bold;margin:0;border:1px solid red;color:red;">'
    expect(inlinedHTML).to.have.string '<input id="input1" style="width:100px;">'
    expect(inlinedHTML).to.have.string '<input id="input3"
    disabled style="width:10px;line-height:24px;background-color:black;">'



describe 'Rendering the Word document', ->
  it 'should return a Word Processing ML file that embeds the altchunk', ->
    expect(internal.renderDocumentFile()).to.match /altChunk r:id="htmlChunk"/

  it 'should set portrait orientation and letter size if no formatting options are passed', ->
    expect(internal.renderDocumentFile()).to
      .match /<w:pgSz w:w="12240" w:h="15840" w:orient="portrait" \/>/

  it 'should set landscape orientation and letter size if orientation is set to landscape', ->
    expect(internal.renderDocumentFile(orientation: 'landscape')).to
      .match /<w:pgSz w:w="15840" w:h="12240" w:orient="landscape" \/>/

  it 'should set default margins if no options were passed', ->
    expect(internal.renderDocumentFile()).to.match /<w:pgMar w:top="1440"/
    expect(internal.renderDocumentFile(orientation: 'landscape')).to.match /<w:pgMar w:top="1440"/

  it 'should set the margin if it was specified as an option', ->
    expect(internal.renderDocumentFile(margins: top: 123)).to.match /<w:pgMa[^>]*w:top="123"/

  it 'should leave default values for margins that are not defined in the options', ->
    expect(internal.renderDocumentFile(margins: left: 123)).to.match /<w:pgMar[^>]*w:left="123"/
    expect(internal.renderDocumentFile(margins: left: 123)).to.match /<w:pgMar[^>]*w:top="1440"/

describe 'Generating the document', ->
  beforeEach ->
    @zip = generate: sinon.stub().returns 'DEADBEEF'

  it 'should retrieve ZIP file as arraybuffer', ->
    internal.generateDocument @zip
    expect(@zip.generate).to.have.been.calledWith type: 'arraybuffer'

  it 'should return Blob with correct content type if it is available', ->
    return unless global.Blob
    document = internal.generateDocument @zip
    expect(document.type).to.be
      .equal 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'

  it 'should return Buffer in Node.js environment', ->
    return unless global.Buffer
    expect(internal.generateDocument @zip).to.be.an.instanceOf Buffer
