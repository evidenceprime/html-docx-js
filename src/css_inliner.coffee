RegExp.escape = (text) ->
  text.replace(/[-[\]{}()*+?.,\\/^$|#\s]/g, "\\$&");

# CONSTANTS
REGULAR_EXPRESSIONS =
  # captures <style> tags content
  cssStylesRegExp: /<style[^>]*>([\s\S]+)<\/style>/
  # captures css rule block
  cssRulesBlockRegExp: /([\.\s\w\d->#\[\]~"=\n\,\:\+\-\(\)\^\&\*\|]+){[\n\s]*([^}])+}/g
  # captures where should the rule applied to
  cssRuleTargetRegExp: /[\s\S]+(?={)/
  # capture the css rule
  cssRuleRegExp: /\{([\s\S]+)\}/
  # parse CSS rule string for separate declaration
  cssDeclarationRegExp: /([^\:]+)\:([^;]+);/g
  # capture pseudo class
  pseudoClassRegExp: /\w+:\w+/
  # capture HTML element attribute
  attrRegExp: /\s([\w-]+(="[^"]+")*)/g
  # capture HTML element classes
  classRegExp: /\sclass="([^"]+)"/
  # capture HTML element id value
  idRegExp: /\sid="([^"]+)"/
  # capture tag
  tagRegExp: /<(\/?)(\w+)[^>]*>/g

SELECTOR_SCORES =
  'tag': 1
  'class': 10
  'attr': 10
  'tagWithClass': 11
  'id': 100

CSS_SELECTOR_MATCHERS =
  'tag': /^\w+$/ # matches tag selectors
  'class': /^\./ # matches class selectors (both one and multi)
  'attr': /\[[^\]]+\]/ # matches attribute selectors
  'tagWithClass': /^\w+(\.\S+)+$/ # matches "h1.small"
  'id': /^#/ # matches ID selector

IGNORE_TAGS = [
  'area'
  'base'
  'br'
  'command'
  'embed'
  'hr'
  'keygen'
  'link'
  'meta'
  'param'
  'source'
  'track'
  'wbr'
  'script'
]

SELF_CLOSING_TAGS = [
  'img'
  'input'
  'col'
]

# HELPER FUNCTIONS
_getCSSDeclarationsObject = (ruleString) ->
  resultObject = {}
  ruleString = ruleString.trim().replace(/\u21b5/g, '')

  while (match = REGULAR_EXPRESSIONS.cssDeclarationRegExp.exec(ruleString))
    declarationName = match[1].trim()
    declarationValue = match[2].trim()
    resultObject[declarationName] = declarationValue
  resultObject

_orderStylesBySpecificity = (stylesObj) ->
  # this function orders all style rules by specificity. rules with less specificity go first
  resultObject = {}
  currentSelectorsOrder = Object.keys stylesObj

  currentSelectorsOrder.sort (sel1, sel2) ->
    stylesObj[sel1].specificity - stylesObj[sel2].specificity
  .forEach (selectorString) ->
    resultObject[selectorString] = stylesObj[selectorString];

  resultObject;

_getCSSSelectorSpecificity = (selectorString) ->
  # used this article as reference:
  # http://www.smashingmagazine.com/2007/07/css-specificity-things-you-should-know/
  # Of course this is not a precise scoring like browser does, but better than nothing
  score = 0;
  # general selectors' score is 0
  generalSelectors = ['.', 'body'];
  selectorParts = selectorString.split ' '

  selectorParts.forEach (partString) ->
    return if partString in generalSelectors

    for selector, selectorRe of CSS_SELECTOR_MATCHERS
      if partString.match selectorRe
        # we must add score for each class if have a multi class selecotr, that is multiply
        # score by the number of classes
        if selector in ['class', 'tagWithClass']
          noOfClasses = partString.split('.').length - 1
          score += SELECTOR_SCORES[selector] * noOfClasses
        else
          score += SELECTOR_SCORES[selector]
  score

_makeInlinedTagString = (stylesObj, tagString) ->
  hasInlinedStyles = /style="[^"]+"/.test tagString
  stylesString = ''

  for declarationName of stylesObj
    declarationValue = stylesObj[declarationName].value
    stylesString += "#{declarationName}:#{declarationValue};"

  if hasInlinedStyles
    tagString.replace /style="([^"]+)"/g, (match, styles) ->
      match.replace styles, styles + stylesString
  else
    stylesString = "style=\"#{stylesString}\""
    tagString.replace '>', " #{stylesString}>"

# EXPORT OBJECT
CSSInliner =
  initialHTML: ''
  inlinedHTML: ''
  stylesObj: {}

  _nodeCounter: 0
  _currentPath: []
  _cache: {}

  nodes: {}
  tag: {}
  id: {}
  class: {}
  attr: {}

  parseHTMLBody: ->
    isProperHTMLDoc = /<body>[\s\S]+<\/body>/.test @initialHTML
    return null unless isProperHTMLDoc

    [inputHTML] = @initialHTML.match(/<body>[\s\S]+<\/body>/)

    while (tagMatch = REGULAR_EXPRESSIONS.tagRegExp.exec(inputHTML))
      isClosingTag = tagMatch[1] is '/'
      match = tagMatch[0]
      tagName = tagMatch[2]
      if isClosingTag
        @_closeCurrentPath()
      else if tagName in IGNORE_TAGS
        continue
      else
        @_parseTagString match, tagName

    this

  parseStyles: ->
    stylesObj = {};
    hasStylesTag = REGULAR_EXPRESSIONS.cssStylesRegExp.test @initialHTML
    if hasStylesTag
      stylesString = @initialHTML.match(REGULAR_EXPRESSIONS.cssStylesRegExp)[1]
      .replace(/\/\*[^\*]+\*\/|\u21b5/g, '').trim() # delete comments, returns and extra spaces
    else
      @stylesObj = null
      return

    # filter out rules whose targets are class-elements, then parse them
    stylesString.match REGULAR_EXPRESSIONS.cssRulesBlockRegExp
    .forEach (cssRuleBlock) =>
      targets = cssRuleBlock.match(REGULAR_EXPRESSIONS.cssRuleTargetRegExp)[0].split(',')
      ruleString = cssRuleBlock.match(REGULAR_EXPRESSIONS.cssRuleRegExp)[1]
      if targets.length > 1
        targets.forEach (target) =>
          @_registerStyles target, ruleString
      else
        @_registerStyles targets[0], ruleString


    @stylesObj = _orderStylesBySpecificity(@stylesObj);
    this;

  _registerStyles: (CSSSelector, rules) ->
    CSSSelector = CSSSelector.trim()
    isPseudoClassSelector = CSSSelector.match REGULAR_EXPRESSIONS.pseudoClassRegExp
    isMediaQuery = CSSSelector.match '@'
    return if isPseudoClassSelector or isMediaQuery

    if CSSSelector of @stylesObj
      existingDeclarations = @stylesObj[CSSSelector].declarations
      newDeclarations = _getCSSDeclarationsObject rules
      # if one and the same CSS selector was used in different blocks like for example:
      #    td {color: red;}
      #    th, td {font-weight: bold; color: blue;}
      # we will extend it with new declarations (like 'font-weight' in "th, td") and at the same
      # time will overwrite any existing declarations (last one wins logic) like 'color'.
      for newDeclarationName, newDeclarationVal of newDeclarations
        existingDeclarations[newDeclarationName] = newDeclarationVal
    else
      @stylesObj[CSSSelector] =
        declarations: _getCSSDeclarationsObject rules
        specificity: _getCSSSelectorSpecificity CSSSelector

  getNodeIdsBySingleSelector: (selectorString) ->
    selectorType = @_getSelectorType(selectorString);

    switch selectorType
      when 'tag' then return @tag[selectorString] or []
      when 'tagWithClass'
        tagAndClassNames = selectorString.split '.'
        tagName = tagAndClassNames.shift(); # now tagAndClassNames contains only classes
        # check if we have a cached result for this selector
        if selectorString of @_cache
          return @_cache[selectorString]
        else
          nodeIdsByClass = @_getNodeIdsByClass tagAndClassNames
          resultingNodeIds = nodeIdsByClass.filter (nodeId) => @nodes[nodeId].tag is tagName
          # cache the result to reduce computations
          @_cache[selectorString] = resultingNodeIds
          return resultingNodeIds
      when 'class'
        classNames = selectorString.split('.').slice(1)
        return @_getNodeIdsByClass classNames
      when 'id'
        idString = selectorString.slice(1)
        return [@id[idString]] or []
      when 'attr'
        parsedSelector = selectorString.match /(\w+)?\[([^=]+)=?([^\]]*)\]/
        [tagName, attrName, attrValue] = parsedSelector.slice(1)
        attrRecord = @attr[attrName]

        return [] unless attrRecord

        attrNodeIds = if attrValue then attrRecord[attrValue] else @attr[attrName]._all
        if tagName
          return [] unless attrNodeIds
          return attrNodeIds.filter (nodeId) => @nodes[nodeId].tag is tagName
        else
          return attrNodeIds;
      else []


  getNodesIdsByCSSSelector: (CSSSelector) ->
    # if CSS selector consists of several selectors like 'div p span' or 'div.main div' we
    # call such single selectors as 'steps'.
    steps = CSSSelector.split ' '
    fullPath = steps.join '&'
    # we do not support child selectors like '~', '+' or '>'
    hasUnsupportedSelectors = steps.some (step) -> step.match /\>|\~|\+/
    return [] if hasUnsupportedSelectors

    finalStep = steps.pop()
    possibleTargets = @getNodeIdsBySingleSelector finalStep

    if steps.length is 0
      return possibleTargets
    else
      # check if we have already calculated previous steps and if so - use them from cache
      parentsPath = steps.join '&'
      if parentsPath of @_cache
        pathNodes = @_cache[parentsPath]
        # for each possible target we check if any of nodes on cached path is present in possbile
        # target's path and if so - it means it is a valid target.
        resultingNodeIds = possibleTargets.filter (possibleTargetId) =>
          pathNodes.some (pathNodeId) =>
            pathNodeId in @nodes[possibleTargetId].path
        # cache the computation
        @_cache[fullPath] = resultingNodeIds
        resultingNodeIds;
      else
        # the idea below is following: we have a possible target node, it has a 'path' attribute
        # which is an array of node ids of its parents all way to the top of the DOM. It means if
        # possible target node is a real target then concatanating all nodeIds of each step with the
        # 'path' ids and then taking values appearing in such concatanated array more than once
        # (let's call them duplicated values just for reference) then to claim that this possible
        # target node is real following must be true:
        #  - all duplicated values appear in possbile target's 'path' array
        #  - at least one id of each step will appear in duplicated array
        parentStepsNodesIdsArray = steps.map (selector) => @getNodeIdsBySingleSelector(selector)
        parentStepsNodesIdsArrayFlatterned = parentStepsNodesIdsArray
        .reduce (stepAIds, stepBIds) ->stepAIds.concat stepBIds

        resultingNodeIds = possibleTargets.filter (possibleTargetId) =>
          possibleTargetPath = @nodes[possibleTargetId].path
          concatanatedIdsArray = possibleTargetPath.concat(parentStepsNodesIdsArrayFlatterned)
          # filter out only those Ids which appear in the concatandated array more than once.
          .filter (nodeId, index, array) -> array.lastIndexOf(nodeId) > index

          concatanatedIdsArray.every((nodeId) -> nodeId in possibleTargetPath) and
          parentStepsNodesIdsArray.every (stepNodeIdsArray) ->
            stepNodeIdsArray.some (nodeId) ->
              nodeId in concatanatedIdsArray
        # cache the computation
        @_cache[fullPath] = resultingNodeIds
        resultingNodeIds

  _closeCurrentPath: ->
    # since we can only move 1 step up at a time when we face a closing tag, all we have to do is
    # delete the last element in path array
    @_currentPath.pop();

  _parseTagString: (tagString, tagName) ->
    nodeObject = @_makeNodeObject tagString, tagName
    @_registerNode nodeObject, tagName

  _makeNodeObject: (tagString, tagName) ->
    nodeObject =
      tag: tagName,
      styles: {},
      path: @_currentPath.slice(),
      classList: []
      tagString: tagString
      attr: []

    nodeClassesMatch = tagString.match REGULAR_EXPRESSIONS.classRegExp
    if nodeClassesMatch
      nodeObject.classList = nodeObject.classList.concat nodeClassesMatch[1].trim().split ' '

    nodeIdMatch = tagString.match REGULAR_EXPRESSIONS.idRegExp
    nodeObject.id = if nodeIdMatch then nodeIdMatch[1] else null

    while (attrMatch = REGULAR_EXPRESSIONS.attrRegExp.exec(tagString))
      attrNameValue = attrMatch[1].split '='
      [attrName, attrValue] = attrNameValue
      if attrName in ['id', 'class', 'src']
        continue
      else
        nodeObject.attr.push name: attrName, value: attrValue

    nodeObject

  _registerNode: (nodeObject, tagName) ->
    nodeUID = ++@_nodeCounter
    nodeClasses = nodeObject.classList
    nodeId = nodeObject.id
    nodeAttrs = nodeObject.attr
    # update the current path if tag is not a self closing tag
    @_currentPath.push(nodeUID) unless tagName in SELF_CLOSING_TAGS
    # record the node
    @nodes[nodeUID] = nodeObject
    # register node by its tag for lookups by tag
    if tagName of @tag
      @tag[tagName].push nodeUID
    else
      tagRecord = @tag[tagName] = []
      tagRecord.push nodeUID
    # register node by its classes for lookups by class
    if nodeClasses.length > 0
      nodeClasses.forEach (className) =>
        if className of @class
          @class[className].push nodeUID
        else
          classRecord = @class[className] = []
          classRecord.push nodeUID
    # register node by its id for lookups by id
    @id[nodeId] = nodeUID if nodeId
    # register node by its attributes for lookups by attributes
    if nodeAttrs.length > 0
      nodeAttrs.forEach (attrObject) =>
        attrName = attrObject.name
        attrValue = attrObject.value
        if attrName of @attr
          registeredAttrbute = @attr[attrName]
          # register the node value (for CSS selectors containing the value of attribute)
          if attrValue
            if attrValue of registeredAttrbute
              registeredAttrbute[attrValue].push nodeUID
            else
              attrValueRecord = registeredAttrbute[attrValue] = []
              attrValueRecord.push nodeUID
          # register the node itself (for CSS selectors containing only attribute name)
          registeredAttrbute._all.push nodeUID
        else
          attrNameRecord = @attr[attrName] = {}
          attrNameRecord._all = []
          attrNameRecord._all.push nodeUID
          if attrValue
            attrValueRecord = attrNameRecord[attrValue] = []
            attrValueRecord.push nodeUID

  _getNodeIdsByClass: (classNames) ->
    firstClass = classNames.shift()
    firstClassRecord = @class[firstClass]

    return [] unless firstClassRecord

    if classNames.length is 0
      firstClassRecord
    else
      firstClassRecord.filter (nodeId) =>
        classNames.every (className) =>
          classRecord = @class[className]
          if classRecord then nodeId in classRecord else false

  _getSelectorType: (selectorString) ->
    for selectorType, selectorRegExp of CSS_SELECTOR_MATCHERS
      return selectorType if selectorString.match selectorRegExp

  _calculateRules: ->
    # There can be several rules affecting one and the same node. We cam either apply them all in
    # the order of specificity (less specific are applied first) having one the same declarations
    # overwritten by more specific rule. But this is extensive approach since we will do unneeded
    # 'write' actions for declarations which will be overwritten.
    Object.keys(@stylesObj).forEach (CSSRuleSelector) =>
      ruleDeclarations = @stylesObj[CSSRuleSelector].declarations
      ruleSpecificity = @stylesObj[CSSRuleSelector].specificity
      targetNodes = @getNodesIdsByCSSSelector CSSRuleSelector

      return if targetNodes.length is 0 or not targetNodes

      targetNodes.forEach (nodeId) =>
        nodeStyles = @nodes[nodeId].styles
        for declarationName, declarationValue of ruleDeclarations
          # if node already has this declaration we either update it if this declaration's specificity
          # is higher or ignore if lower.
          if declarationName of nodeStyles
            nodeSavedDeclaration = nodeStyles[declarationName]
            if ruleSpecificity > nodeSavedDeclaration.specificity
              nodeSavedDeclaration.value = declarationValue
              nodeSavedDeclaration.specificity = ruleSpecificity
            else
              continue
          else
            # if node doesn't have this declaration we create new record for it saving the value and
            # specificity.
            newDeclarationRecord = nodeStyles[declarationName] = {}
            newDeclarationRecord.value = declarationValue
            newDeclarationRecord.specificity = ruleSpecificity

  _clean: ->
    @initialHTML= ''
    @inlinedHTML= ''
    @stylesObj= {}

    @_nodeCounter= 0
    @_currentPath= []
    @_cache= {}

    @nodes= {}
    @tag= {}
    @id= {}
    @class= {}
    @attr= {}

  getInlinedHTML: (htmlSource) ->
    @_clean()
    @initialHTML = htmlSource
    @parseHTMLBody()
    @parseStyles()

    # if not a valid HTML document was supplied or there are no styles - return the input data back
    return @initialHTML if @_nodeCounter is 0 or not @stylesObj

    @_calculateRules()

    for node of @nodes
      styles = @nodes[node].styles
      continue if Object.keys(styles).length is 0  # nothing to inline

      tagString = @nodes[node].tagString
      newTagString = _makeInlinedTagString styles, tagString
      nodeRegExp = new RegExp RegExp.escape tagString
      # replace each node with one with inlined styles
      @inlinedHTML = if @inlinedHTML
        @inlinedHTML.replace nodeRegExp, newTagString
      else
        @initialHTML.replace nodeRegExp, newTagString
    @inlinedHTML

module.exports = CSSInliner
