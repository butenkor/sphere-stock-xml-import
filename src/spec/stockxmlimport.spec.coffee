xmlHelpers = require '../lib/xmlhelpers.js'
StockXmlImport = require('../main').StockXmlImport

describe 'StockXmlImport', ->
  beforeEach ->
    @import = new StockXmlImport {}

  it 'should initialize', ->
    expect(@import).toBeDefined()

describe '#run', ->
  beforeEach ->
    @import = new StockXmlImport {}

  it 'should throw error if no XML string is passed', ->
    expect(=> @import.run()).toThrow new Error('String required')

  it 'should throw error if callback is passed', ->
    expect(=> @import.run("")).toThrow new Error('Callback must be a function')

  xit 'should give feedback on xml parse problems', (done) ->
    @import.run "<foo><foo>", (data) ->
      expect(data.status).toBe false
      expect(data.message).toMatch /Error on parsing XML/
      done()

describe '#transform', ->
  beforeEach ->
    @import = new StockXmlImport {}

  it 'simple entry', (done) ->
    rawXml =
      '''
      <root>
        <row>
          <code>1</code>
          2
        </row>
      </root>
      '''
    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '1'
      expect(s.quantityOnStock).toBe 2
      done()

  it 'should map delivery date', (done) ->
    rawXml =
      '''
      <root>
        <row>
          <code>2</code>
          7.000
          <CommittedDeliveryDate>2013-11-19T00:00:00</CommittedDeliveryDate>
        </row>
      </root>
      '''
    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '2'
      expect(s.quantityOnStock).toBe 7
      expect(s.expectedDelivery).toBeUndefined()
      done()

  it 'should map an extra entry for AppointedQuantity', (done) ->
    rawXml =
      '''
      <root>
        <row>
          <code>foo-bar</code>
          7.000
          <deliverydate>2013-11-05T00:00:00</deliverydate>
          <AppointedQuantity>12.000</AppointedQuantity>
        </row>
      </root>
      '''
    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root, 'myChannelId'
      expect(stocks.length).toBe 2
      s = stocks[0]
      expect(s.sku).toBe 'foo-bar'
      expect(s.quantityOnStock).toBe 7
      expect(s.expectedDelivery).toBeUndefined()
      s = stocks[1]
      expect(s.sku).toBe 'foo-bar'
      expect(s.quantityOnStock).toBe 12
      expect(s.expectedDelivery).toBe '2013-11-05T00:00:00.000Z'
      expect(s.supplyChannel.typeId).toBe 'channel'
      expect(s.supplyChannel.id).toBe 'myChannelId'
      done()

  it 'should use CommittedDeliveryDate over deliverydate', (done) ->
    rawXml =
      '''
      <root>
        <row>
          <code>foo-bar</code>
          7.000
          <deliverydate>2013-11-05T00:00:00</deliverydate>
          <AppointedQuantity>12.000</AppointedQuantity>
          <CommittedDeliveryDate>2013-11-19T00:00:00</CommittedDeliveryDate>
        </row>
      </root>
      '''
    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root, 'myChannelId'
      expect(stocks.length).toBe 2
      s = stocks[0]
      expect(s.sku).toBe 'foo-bar'
      expect(s.quantityOnStock).toBe 7
      expect(s.expectedDelivery).toBeUndefined()
      expect(s.supplyChannel).toBeUndefined()
      s = stocks[1]
      expect(s.sku).toBe 'foo-bar'
      expect(s.quantityOnStock).toBe 12
      expect(s.expectedDelivery).toBe '2013-11-19T00:00:00.000Z'
      expect(s.supplyChannel.typeId).toBe 'channel'
      expect(s.supplyChannel.id).toBe 'myChannelId'
      done()