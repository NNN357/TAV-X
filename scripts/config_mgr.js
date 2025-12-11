/**
 * TAV-X Configuration Manager
 */

const fs = require('fs');
const path = require('path');

const INSTALL_DIR = process.env.INSTALL_DIR || path.join(process.env.HOME, 'SillyTavern');
const CONFIG_PATH = path.join(INSTALL_DIR, 'config.yaml');

const args = process.argv.slice(2);
const action = args[0];

if (!action || args.length < 2) {
    console.error("Usage: node config_mgr.js [get|set|set-batch] [key|json] [value]");
    process.exit(1);
}

if (!fs.existsSync(CONFIG_PATH)) {
    console.error(`❌ Config file not found: ${CONFIG_PATH}`);
    process.exit(1);
}

let fileContent = fs.readFileSync(CONFIG_PATH, 'utf8');
let lines = fileContent.split(/\r?\n/);

if (action === 'get') {
    const keyToFind = args[1];
    const val = getValue(lines, keyToFind);
    if (val !== null) {
        console.log(val);
        process.exit(0);
    } else {
        process.exit(1);
    }
} 

else if (action === 'set') {
    const key = args[1];
    const val = args[2];
    const result = applyChange(lines, key, val);
    
    if (result.changed) {
        writeAtomic(result.lines);
        console.log(`✅ Updated [${key}] -> ${val}`);
    } else {
    }
} 

else if (action === 'set-batch') {
    let updates = {};
    try {
        updates = JSON.parse(args[1]);
    } catch (e) {
        console.error("❌ Invalid JSON for batch update");
        process.exit(1);
    }

    let globalChanged = false;
    Object.keys(updates).forEach(key => {
        const result = applyChange(lines, key, updates[key]);
        if (result.changed) {
            lines = result.lines;
            globalChanged = true;
            console.log(`✅ Set [${key}] -> ${updates[key]}`);
        }
    });

    if (globalChanged) {
        writeAtomic(lines);
    }
} 

else {
    console.error(`❌ Unknown action: ${action}`);
    process.exit(1);
}

function writeAtomic(linesData) {
    const tempPath = CONFIG_PATH + '.tmp';
    try {
        fs.writeFileSync(tempPath, linesData.join('\n'), 'utf8');
        const fd = fs.openSync(tempPath, 'r+');
        fs.fsyncSync(fd);
        fs.closeSync(fd);
        fs.renameSync(tempPath, CONFIG_PATH);
    } catch (err) {
        console.error(`❌ Write Failed: ${err.message}`);
        try { fs.unlinkSync(tempPath); } catch(e){}
        process.exit(1);
    }
}

function getValue(lines, keyPath) {
    const keys = keyPath.split('.');
    let currentDepth = 0;
    let indentStack = [-1];

    for (const line of lines) {
        if (!line.trim() || line.trim().startsWith('#')) continue;

        const indent = getIndent(line);
        const key = getKey(line);

        while (indent <= indentStack[currentDepth] && currentDepth > 0) {
            currentDepth--;
        }

        if (key === keys[currentDepth]) {
            indentStack[currentDepth + 1] = indent;
            if (currentDepth === keys.length - 1) {
                const { val } = parseValue(line);
                return val.replace(/^['"]|['"]$/g, '');
            }
            currentDepth++;
        }
    }
    return null;
}

function applyChange(currentLines, keyPath, val) {
    const keys = keyPath.split('.');
    let currentDepth = 0;
    let indentStack = [-1];
    let isChanged = false;

    const newLines = currentLines.map((line) => {
        if (!line.trim() || line.trim().startsWith('#')) return line;

        const indent = getIndent(line);
        const key = getKey(line);

        while (indent <= indentStack[currentDepth] && currentDepth > 0) {
            currentDepth--;
        }

        if (key === keys[currentDepth]) {
            indentStack[currentDepth + 1] = indent;
            if (currentDepth === keys.length - 1) {
                const { val: currVal, comment } = parseValue(line);
                if (areValuesEqual(currVal, val)) return line;

                isChanged = true;
                const keyPart = line.substring(0, line.indexOf(':') + 1);
                return `${keyPart} ${val}${comment}`;
            } 
            currentDepth++;
        }
        return line;
    });

    return { lines: newLines, changed: isChanged };
}

function getIndent(line) {
    const match = line.match(/^(\s*)/);
    return match ? match[1].length : 0;
}

function getKey(line) {
    const match = line.match(/^\s*(?:['"]?([\w\-\.]+)['"]?)\s*:/);
    return match ? match[1] : null;
}

function parseValue(line) {
    const colIdx = line.indexOf(':');
    if (colIdx === -1) return { val: '', comment: '' };
    
    let rawVal = line.substring(colIdx + 1);
    let inQuote = false;
    let quoteChar = '';
    let commentIdx = -1;

    for (let i = 0; i < rawVal.length; i++) {
        const char = rawVal[i];
        
        if (char === '"' || char === "'") {
            if (!inQuote) {
                inQuote = true;
                quoteChar = char;
            } else if (char === quoteChar) {
                inQuote = false;
            }
        }
        if (!inQuote && char === '#') {
            commentIdx = i;
            break;
        }
    }

    if (commentIdx !== -1) {
        return {
            val: rawVal.substring(0, commentIdx).trim(),
            comment: rawVal.substring(commentIdx)
        };
    }
    
    return { val: rawVal.trim(), comment: '' };
}

function areValuesEqual(fileVal, inputVal) {
    const cleanFile = String(fileVal).replace(/^['"]|['"]$/g, '').trim();
    const cleanInput = String(inputVal).replace(/^['"]|['"]$/g, '').trim();
    if ((cleanFile === 'true' && cleanInput === 'true') || 
        (cleanFile === 'false' && cleanInput === 'false')) {
        return true;
    }
    return cleanFile === cleanInput;
}