_ = require('underscore')._
xmlHelpers = require '../lib/xmlhelpers.js'
Config = require '../config'
InventorySync = require('sphere-node-sync').InventorySync

Q = require 'q'
ProgressBar = require 'progress'

exports.StockXmlImport = (options) ->
  @_options = options
  @sync = new InventorySync Config
  @rest = @sync._rest
  @existingStocks = {}
  @sku2index = {}
  @

exports.StockXmlImport.prototype.elasticio = (msg, cfg, cb, snapshot) ->
  if msg.attachments
    for attachment of msg.attachments
      continue if not attachment.match /xml$/i
      content = msg.attachments[attachment].content
      continue if not content
      xmlString = new Buffer(content, 'base64').toString()
      @run xmlString, cb
  else if msg.body
    @initMatcher().then () =>
      @createOrUpdate([@createEntry(msg.body.SKU, msg.body.QUANTITY)], cb)
  else
    @returnResult false, 'No data found in elastic.io msg.', cb

exports.StockXmlImport.prototype.run = (xmlString, callback) ->
  throw new Error 'String required' unless _.isString xmlString
  throw new Error 'Callback must be a function' unless _.isFunction callback

  @initMatcher().then () =>
    xmlHelpers.xmlTransform xmlHelpers.xmlFix(xmlString), (err, result) =>
      if err
        @returnResult false, "Error on parsing XML: " + err, callback
      else
        stocks = @mapStock result.root, "TODO"
        @createOrUpdate stocks, callback

exports.StockXmlImport.prototype.returnResult = (positiveFeedback, msg, callback) ->
  d =
    message:
      status: positiveFeedback
      msg: msg
  console.log 'Error occurred: %j', d if not positiveFeedback
  callback d

exports.StockXmlImport.prototype.createOrUpdate = (stocks, callback) ->
  posts = []
  bar = new ProgressBar 'Updating stock [:bar] :percent done', { width: 50, total: stocks.length }
  for s in stocks
    es = @match(s)
    if es
      posts.push @update(s, es, bar)
    else
      posts.push @create(s, bar)

  Q.all(posts).then (v) =>
    if v.length is 1
      v = v[0]
    else
      v = "#{v.length} Done"
    @returnResult true, v, callback
  .fail (v) =>
    @returnResult false, v, callback

exports.StockXmlImport.prototype.initMatcher = (rest) ->
  deferred = Q.defer()
  @rest.GET "/inventory?limit=0", (error, response, body) =>
    if error
      deferred.reject 'Problem on getting existing stock information.'
      return
    if response.statusCode != 200
      deferred.reject 'Can not fetch stock information.'
      return
    @existingStocks = JSON.parse(body).results
    for es, i in @existingStocks
      @sku2index[es.sku] = i
    deferred.resolve @existingStocks
  deferred.promise

exports.StockXmlImport.prototype.match = (s) ->
  if @sku2index[s.sku] >= 0
    @existingStocks[@sku2index[s.sku]]

exports.StockXmlImport.prototype.update = (s, es, bar) ->
  deferred = Q.defer()
  @sync.buildActions(s, es).update (error, response, body) =>
    bar.tick()
    if error
      deferred.reject 'Error on updating stock.' + error
    else
      if response.statusCode is 200
        deferred.resolve 'Stock updated'
      else if response.statusCode is 304
        deferred.resolve 'Stock update not neccessary'
      else
        @deferred.reject 'Problem on updating existing stock.' + body
  deferred.promise

exports.StockXmlImport.prototype.create = (stock, bar) ->
  deferred = Q.defer()
  @rest.POST '/inventory', JSON.stringify(stock), (error, response, body) ->
    bar.tick()
    if error
      deferred.reject 'Error on creating new stock.' + error
    else
      if response.statusCode is 201
        deferred.resolve 'New stock created'
      else
        deferred.reject 'Problem on creating new stock.' + body
  deferred.promise

exports.StockXmlImport.prototype.mapStock = (xmljs, channelId) ->
  stocks = []
  for k,row of xmljs.row
    sku = xmlHelpers.xmlVal row, 'code'
    stocks.push @createEntry(sku, xmlHelpers.xmlVal(row, 'quantity'), xmlHelpers.xmlVal(row, 'CommittedDeliveryDate'))
    expectedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
    if expectedQuantity
      d = @createEntry(sku, expectedQuantity, xmlHelpers.xmlVal(row, 'deliverydate'))
      c =
        typeId: 'channel'
        id: channelId
      d.supplyChannel = c
      stocks.push d
  stocks

exports.StockXmlImport.prototype.createEntry = (sku, quantity, expectedDelivery) ->
  d =
    sku: sku
    quantityOnStock: parseInt(quantity)
  d.expectedDelivery = expectedDelivery if expectedDelivery
  d
