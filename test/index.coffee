chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
chai.use require 'sinon-chai'
internal = require '../src/internal'

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
    internal.addFiles zip(@data), 'foobar'

  it 'should add file for embedded content types', ->
    expect(@data['[Content_Types].xml']).to.be.defined
    content = String(@data['[Content_Types].xml'])
    expect(content).to.match /Extension="htm"/
    expect(content).to.match /Extension="xml"/
    expect(content).to.match /Extension="rels"/

  it 'should add manifest for Word document', ->
    expect(@data._rels['.rels']).to.be.defined
    content = String(@data._rels['.rels'])
    expect(content).to.match /Target="\/word\/document.xml"/

  it 'should add HTML file with given content', ->
    expect(@data.word['afchunk.htm']).to.be.defined
    expect(String @data.word['afchunk.htm']).to.equal 'foobar'

  it 'should add Word file with altChunk element', ->
    expect(@data.word['document.xml']).to.be.defined
    expect(String @data.word['document.xml']).to.match /altChunk r:id="htmlChunk"/

  it 'should add relationship file to link between Word and HTML files', ->
    expect(@data.word._rels['document.xml.rels']).to.be.defined
    expect(String @data.word._rels['document.xml.rels']).to
      .match /Target="\/word\/afchunk.htm" Id="htmlChunk"/

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
