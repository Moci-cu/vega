function splitFields(line) {
    const fields = [];
    let field = "";
    let escaped = false;

    for (const character of line) {
        if (escaped) {
            field += character;
            escaped = false;
        } else if (character === "\\") {
            escaped = true;
        } else if (character === ":") {
            fields.push(field);
            field = "";
        } else {
            field += character;
        }
    }
    fields.push(escaped ? field + "\\" : field);
    return fields;
}

function parseLine(line) {
    const fields = splitFields(line);
    if (fields.length !== 7 || fields[1].trim().length === 0)
        return null;
    return {
        active: fields[0].trim() === "*",
        ssid: fields[1],
        signal: Number(fields[2]) || 0,
        rate: fields[3],
        security: fields[4] === "--" ? "" : fields[4],
        channel: fields[5],
        bssid: fields[6]
    };
}

function parse(output) {
    const networks = [];
    for (const line of String(output ?? "").split("\n")) {
        if (!line.trim()) continue;
        const network = parseLine(line);
        if (!network) continue;
        // ponytail: Wi-Fi lists are tiny; replace with a map only if this is ever measured hot.
        const index = networks.findIndex(entry => entry.ssid === network.ssid);
        if (index < 0) {
            networks.push(network);
        } else if (network.active || network.signal > networks[index].signal) {
            networks[index] = network;
        }
    }
    return networks.sort((left, right) => Number(right.active) - Number(left.active)
        || right.signal - left.signal || left.ssid.localeCompare(right.ssid));
}
