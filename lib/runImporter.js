/* ===========================================================
# sphere-stock-xml-import - v0.0.3
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var Config, StockXmlImport, fileName, fs, stockxmlimport;

fs = require('fs');

Config = require('../config');

StockXmlImport = require('../main').StockXmlImport;

Config.timeout = 120000;

stockxmlimport = new StockXmlImport(Config);

fileName = '';

process.argv.forEach(function(val, index, array) {
  if (index === 2) {
    return fileName = val;
  }
});

fs.readFile(fileName, 'utf8', function(err, content) {
  if (err) {
    console.error('Problems on reading file: ' + error);
    process.exit(1);
  }
  return stockxmlimport.run(content, function(result) {
    console.log(result);
    if (!result.status) {
      return process.exit(2);
    }
  });
});
