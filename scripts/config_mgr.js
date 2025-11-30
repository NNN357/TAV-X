/**
 * TAV-X Configuration Manager (The Scalpel) v1.1
 * 新增: 完善 get 功能，用于脚本读取配置
 */

const fs = require('fs');
const path = require('path');

const ST_DIR = process.env.INSTALL_DIR || path.join(process.env.HOME, 'SillyTavern');
const CONFIG_PATH = path.join(ST_DIR, 'config.yaml');

if (!fs.existsSync(CONFIG_PATH)) {
    process.exit(1);
}

const args = process.argv.slice(2);
const action = args[0]; 
const keyPath = args[1]; 
const newValue = args[2]; 

if (!action || !keyPath) process.exit(1);

let content = fs.readFileSync(CONFIG_PATH, 'utf8');
const lines = content.split('\n');

function getIndent(line) {
    const match = line.match(/^(\s*)/);
    return match ? match[1].length : 0;
}

function getKey(line) {
    const match = line.match(/^\s*([\w]+):/);
    return match ? match[1] : null;
}

if (action === 'get') {
    const keys = keyPath.split('.');
    let keyIndex = 0;
    
    for (const line of lines) {
        if (line.trim().startsWith('#') || line.trim() === '') continue;

        const indent = getIndent(line);
        const key = getKey(line);
        const targetKey = keys[keyIndex];

        if (indent === keyIndex * 2 && key === targetKey) {
            if (keyIndex === keys.length - 1) {
                let val = line.replace(/^\s*[\w]+:\s*/, '').split('#')[0].trim();
                
                val = val.replace(/^['"]|['"]$/g, '');
                
                console.log(val);
                process.exit(0);
            } else {
                keyIndex++;
            }
        }
    }
    process.exit(1);
} 
else if (action === 'set') {
    if (newValue === undefined) process.exit(1);
    const keys = keyPath.split('.');
    let keyIndex = 0;
    let pathFound = false;

    const newLines = lines.map(line => {
        if (pathFound && keyIndex >= keys.length) return line;
        if (line.trim().startsWith('#') || line.trim() === '') return line;

        const indent = getIndent(line);
        const key = getKey(line);
        if (indent === keyIndex * 2 && key === keys[keyIndex]) {
            if (keyIndex === keys.length - 1) {
                pathFound = true;
                console.error(`✅ Update: ${keyPath} -> ${newValue}`);
                return line.replace(/:\s*.*/, `: ${newValue}`);
            } else {
                keyIndex++;
            }
        }
        return line;
    });

    if (pathFound) {
        fs.writeFileSync(CONFIG_PATH, newLines.join('\n'), 'utf8');
    } else {
        console.error(`❌ Key not found: ${keyPath}`);
    }
}
