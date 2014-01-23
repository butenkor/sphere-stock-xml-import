/* ===========================================================
# sphere-stock-xml-import - v0.0.22
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var InventoryUpdater, Q, StockXmlImport, package_json, xmlHelpers, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

_ = require('underscore')._;

xmlHelpers = require('../lib/xmlhelpers');

package_json = require('../package.json');

InventoryUpdater = require('sphere-node-sync').InventoryUpdater;

Q = require('q');

StockXmlImport = (function(_super) {
  __extends(StockXmlImport, _super);

  function StockXmlImport(options) {
    if (!_.isEmpty(options)) {
      options.user_agent = "" + package_json.name + " - " + package_json.version;
    }
    StockXmlImport.__super__.constructor.call(this, options);
  }

  StockXmlImport.prototype.elasticio = function(msg, cfg, cb, snapshot) {
    var attachment, content, xmlString, _results,
      _this = this;
    if (_.size(msg.attachments) > 0) {
      _results = [];
      for (attachment in msg.attachments) {
        if (!attachment.match(/xml$/i)) {
          continue;
        }
        content = msg.attachments[attachment].content;
        if (!content) {
          continue;
        }
        xmlString = new Buffer(content, 'base64').toString();
        _results.push(this.run(xmlString, cb));
      }
      return _results;
    } else if (_.size(msg.body) > 0) {
      return this.initMatcher().then(function() {
        return _this.createOrUpdate([_this.createInventoryEntry(msg.body.SKU, msg.body.QUANTITY)], cb);
      }).fail(function(msg) {
        return _this.returnResult(false, msg, cb);
      });
    } else {
      return this.returnResult(false, 'No data found in elastic.io msg.', cb);
    }
  };

  StockXmlImport.prototype.run = function(xmlString, callback) {
    var _this = this;
    if (!_.isString(xmlString)) {
      throw new Error('String required');
    }
    if (!_.isFunction(callback)) {
      throw new Error('Callback must be a function');
    }
    return xmlHelpers.xmlTransform(xmlHelpers.xmlFix(xmlString), function(err, result) {
      if (err) {
        return _this.returnResult(false, 'Error on parsing XML: ' + err, callback);
      } else {
        return _this.ensureChannelByKey(_this.rest, 'expectedStock').then(function(channel) {
          var stocks;
          stocks = _this.mapStock(result.root, channel.id);
          return _this.initMatcher().then(function() {
            return _this.createOrUpdate(stocks, callback);
          }).fail(function(msg) {
            return _this.returnResult(false, msg, callback);
          });
        }).fail(function(msg) {
          return _this.returnResult(false, msg, callback);
        });
      }
    });
  };

  StockXmlImport.prototype.mapStock = function(xmljs, channelId) {
    var d, expectedQuantity, k, row, sku, stocks, _ref;
    stocks = [];
    _ref = xmljs.row;
    for (k in _ref) {
      row = _ref[k];
      sku = xmlHelpers.xmlVal(row, 'code');
      stocks.push(this.createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'), xmlHelpers.xmlVal(row, 'CommittedDeliveryDate')));
      expectedQuantity = xmlHelpers.xmlVal(row, 'AppointedQuantity');
      if (expectedQuantity) {
        d = this.createInventoryEntry(sku, expectedQuantity, xmlHelpers.xmlVal(row, 'deliverydate'), channelId);
        stocks.push(d);
      }
    }
    return stocks;
  };

  return StockXmlImport;

})(InventoryUpdater);

module.exports = StockXmlImport;
