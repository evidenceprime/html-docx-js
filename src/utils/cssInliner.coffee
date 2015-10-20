CSSOM = require 'cssom'
_ =
  compose: require 'lodash.flowright'
  curry: require 'lodash.curry'

forEach = _.curry (list, fn) ->
  [].forEach.call list, fn

STYLE_TAG_REG_EXP = /<style[^>]*>([\s\S]+)<\/style>/

_isHTMLObject = (input) ->
  input.toString() is '[object HTMLDocument]'

_HTMLStringToDoc = (htmlSource) ->
  fakeDoc = document.implementation.createHTMLDocument()
  fakeDoc.documentElement.innerHTML = htmlSource.replace /<\/*html[^>]*>/, ''
  fakeDoc

_convertToHTMLDocument = (html) ->
  if _isHTMLObject html
    html.cloneNode true
  else
    _HTMLStringToDoc html

_getStylesString = (htmlSource) ->
  if _isHTMLObject htmlSource
    styleTag = htmlSource.getElementsByTagName('style')[0]
    return '' unless styleTag
    styleTag.innerText
  else
    hasStyleTag = STYLE_TAG_REG_EXP.test htmlSource
    return '' unless hasStyleTag
    # delete comments, returns and extra spaces
    htmlSource.match(STYLE_TAG_REG_EXP)[1].replace(/\/\*[^\*]+\*\/|\u21b5/g, '').trim()

_parseStyles = _.compose CSSOM.parse, _getStylesString

_getDeclarations = (CSSRule) ->
  result = {}
  stylesObj = CSSRule.style
  return result unless stylesObj

  rulesNo = stylesObj.length - 1
  for idx in [0..rulesNo]
    result[stylesObj[idx]] = stylesObj[stylesObj[idx]]
  result

_getTargetsList = (doc, CSSRule) ->
  selector = CSSRule.selectorText
  return [] unless selector
  [].slice.call doc.querySelectorAll selector

_applyStylesToElement = (declarations, el) ->
  for declarationName, declarationVal of declarations
    el.style[declarationName] = declarationVal

module.exports = (htmlSource) ->
  stylesObj = _parseStyles htmlSource
  return htmlSource if stylesObj.cssRules.length is 0

  doc = _convertToHTMLDocument htmlSource
  stylesObj.cssRules.forEach (CSSRule) ->
    declarations = _getDeclarations CSSRule
    targets = _getTargetsList doc, CSSRule
    targets.forEach (target) ->
      _applyStylesToElement declarations, target

  doc.documentElement.outerHTML
