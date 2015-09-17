chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
chai.use require 'sinon-chai'
internal = require '../build/internal'
utils = require '../build/utils'

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
