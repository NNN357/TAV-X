/**
 * TAV-X Configuration Manager (The Scalpel) v2.0
 * Update: Robust Indentation, Comment Preservation, Type Handling
 */

const fs = require('fs');
const path = require('path');

const INSTALL_DIR = process.env.INSTALL_DIR || path.join(process.env.HOME, 'SillyTavern');
const CONFIG_PATH = path.join(INSTALL_DIR, 'config.yaml');

if (!fs.existsSync(CONFIG_PATH)) {
    console.error(`❌ Config file not found: ${CONFIG_PATH}`);
    process.exit(1);
}

const args = process.argv.slice(2);
const action = args[0]; 
const keyPath = args[1]; 
let newValue = args[2]; 

if (!action || !keyPath) {
    console.error("Usage: node config_mgr.js [get|set] [key.path] [value]");
    process.exit(1);
}

let content = fs.readFileSync(CONFIG_PATH, 'utf8');
const lines = content.split('\n');

function getIndent(line) {
    const match = line.match(/^(\s*)/);
    return match ? match[1].length : 0;
}

function getKey(line) {
    const match = line.match(/^\s*([\w\-]+):/);
    return match ? match[1] : null;
}

function parseLineValue(line) {
    const match = line.match(/:\s*(.*)/);
    if (!match) return { val: '', comment: '' };
    
    const raw = match[1];
    const commentIdx = raw.indexOf('#');
    
    if (commentIdx !== -1) {
        return {
            val: raw.substring(0, commentIdx).trim(),
            comment: raw.substring(commentIdx) // 保留 # 及后面的内容
        };
    }
    return { val: raw.trim(), comment: '' };
}

if (action === 'get') {
    const keys = keyPath.split('.');
    let currentDepth = 0;
    
    for (const line of lines) {
        if (line.trim().startsWith('#') || line.trim() === '') continue;

        const indent = getIndent(line);
        const key = getKey(line);
        const targetKey = keys[currentDepth];

        if (key === targetKey) {
            if (currentDepth === keys.length - 1) {
                const { val } = parseLineValue(line);
                const cleanVal = val.replace(/^['"]|['"]$/g, '');
                console.log(cleanVal);
                process.exit(0);
            } else {
                currentDepth++;
            }
        }
    }
    process.exit(1);
} 

// --- SET 模式 ---
else if (action === 'set') {
    if (newValue === undefined) process.exit(1);
    
    const keys = keyPath.split('.');
    let currentDepth = 0;
    let pathFound = false;

    const newLines = lines.map(line => {
        if (pathFound && currentDepth >= keys.length) return line;
        
        if (line.trim().startsWith('#') || line.trim() === '') return line;

        const key = getKey(line);
        
        if (key === keys[currentDepth]) {
            if (currentDepth === keys.length - 1) {
                pathFound = true;
                
                const indentStr = line.match(/^(\s*)/)[1];
                const { comment } = parseLineValue(line);
                
                let finalVal = newValue;
                
                let newLine = `${indentStr}${key}: ${finalVal}`;
                
                if (comment) {
                    newLine += ` ${comment}`;
                }
                
                return newLine;
            } else {
                currentDepth++;
            }
        }
        return line;
    });

    if (pathFound) {
        fs.writeFileSync(CONFIG_PATH, newLines.join('\n'), 'utf8');
        process.exit(0);
    } else {
        console.error(`❌ [Config] Key not found: ${keyPath}`);
        process.exit(1);
    }
}