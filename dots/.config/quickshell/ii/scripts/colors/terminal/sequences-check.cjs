const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const sequences = fs.readFileSync(path.join(__dirname, 'sequences.txt'), 'utf8');
const commands = sequences.split('\x1b]').slice(1);
assert(commands.length > 0, 'Expected terminal color commands');
for (const command of commands) {
    assert(command.endsWith('\x1b\\') || command.endsWith('\x1b\\\n'),
        'Every OSC command must terminate before terminal input resumes');
}
console.log('PASS: all terminal color sequences are terminated');
