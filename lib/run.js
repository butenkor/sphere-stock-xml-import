/* ===========================================================
# sphere-stock-xml-import - v0.0.26
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var StockXmlImport, argv, fs, options, stockxmlimport, timeout;

StockXmlImport = require('../main').StockXmlImport;

fs = require('fs');

argv = require('optimist').usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --xmlfile file --timeout timeout').demand(['projectKey', 'clientId', 'clientSecret', 'xmlfile']).argv;

timeout = argv.timeout;

timeout || (timeout = 60000);

options = {
  config: {
    project_key: argv.projectKey,
    client_id: argv.clientId,
    client_secret: argv.clientSecret
  },
  timeout: timeout
};

stockxmlimport = new StockXmlImport(options);

fs.readFile(argv.xmlfile, 'utf8', function(err, content) {
  if (err) {
    console.error(("Problems on reading file '" + argv.xmlfile + "': ") + err);
    process.exit(2);
  }
  return stockxmlimport.run(content, function(result) {
    console.log(result);
    if (!result.status) {
      return process.exit(1);
    }
  });
});
