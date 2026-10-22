import { createInterface } from 'node:readline/promises';

export async function prompt(label, validate, secret = false) {
  while (true) {
    let value;
    if (secret) {
      if (!process.stdin.isTTY) throw new Error('Secret entry requires an interactive console. Double-click Setup Ancient Nest.cmd.');
      process.stdout.write(`${label}: `);
      value = await new Promise((resolve, reject) => {
        let buffer = '';
        process.stdin.setRawMode(true);
        process.stdin.setEncoding('utf8');
        process.stdin.resume();
        const finish = () => {
          process.stdin.removeListener('data', onData);
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdout.write('\n');
        };
        const onData = data => {
          for (const char of data) {
            if (char === '\u0003') { finish(); reject(new Error('Setup cancelled.')); return; }
            if (char === '\r' || char === '\n') { finish(); resolve(buffer); return; }
            if (char === '\u007f' || char === '\b') buffer = buffer.slice(0, -1);
            else if (char >= ' ') buffer += char;
          }
        };
        process.stdin.on('data', onData);
      });
    } else {
      const reader = createInterface({ input: process.stdin, output: process.stdout });
      try { value = await reader.question(`${label}: `); } finally { reader.close(); }
    }
    value = value.trim();
    if (validate(value)) return value;
    console.log('That value is missing or has an invalid format. Please try again.');
  }
}

