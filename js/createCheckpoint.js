var Connector = require("@bengler/pebbles-client").Connector;

module.exports = createCheckpoint;

function createCheckpoint(baseUrl) {
  var connector = new Connector({
    baseUrl: baseUrl,
    clientClasses: require("pebbles-client/clients")
  });

  connector.use({
    checkpoint: 1
  });

  return connector.checkpoint;
}