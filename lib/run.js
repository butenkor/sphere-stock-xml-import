/* ===========================================================
# sphere-stock-xml-import - v0.0.16
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var Config, StockXmlImport, argv, fs, stockxmlimport;

fs = require('fs');

Config = require('../config');

argv = require('optimist').usage('Usage: $0 --xmlfile file').demand(['xmlfile']).argv;

StockXmlImport = require('../main').StockXmlImport;

stockxmlimport = new StockXmlImport(Config);

fs.readFile(argv.xmlfile, 'utf8', function(err, content) {
  if (err) {
    console.error('Problems on reading file: ' + error);
    process.exit(2);
  }
  return stockxmlimport.run(content, function(result) {
    console.log(result);
    if (!result.status) {
      return process.exit(1);
    }
  });
});
