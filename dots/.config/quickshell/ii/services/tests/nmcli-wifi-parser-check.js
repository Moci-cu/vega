const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const parser = {};
vm.runInNewContext(fs.readFileSync(`${__dirname}/../NmcliWifiParser.js`, "utf8"), parser);

const networks = parser.parse([
    " :Cafe\\:5G:62:130 Mbit/s:WPA2:44:AA\\:BB\\:CC\\:DD\\:EE\\:01",
    "*:ciksu:74:65 Mbit/s:WPA2:149:9A\\:20\\:25\\:52\\:49\\:10",
    " :ciksu:55:65 Mbit/s:WPA2:1:9A\\:20\\:25\\:52\\:49\\:11"
].join("\n"));

assert.equal(networks.length, 2);
assert.deepEqual(JSON.parse(JSON.stringify(networks[0])), {
    active: true,
    ssid: "ciksu",
    signal: 74,
    rate: "65 Mbit/s",
    security: "WPA2",
    channel: "149",
    bssid: "9A:20:25:52:49:10"
});
assert.equal(networks[1].ssid, "Cafe:5G");
