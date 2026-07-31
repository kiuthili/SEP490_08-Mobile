const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        const dirPath = path.join(dir, f);
        const isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function processFile(filePath) {
    if (!filePath.endsWith('.dart')) return;
    let content = fs.readFileSync(filePath, 'utf8');
    let original = content;

    // 1. Remove shape: RoundedRectangleBorder(...) inside styleFrom()
    const btnRegex = /(ElevatedButton|FilledButton|OutlinedButton|TextButton)\.styleFrom\s*\(([\s\S]*?)\)/g;
    
    content = content.replace(btnRegex, (match, btnType, styleArgs) => {
        let newArgs = styleArgs.replace(/shape:\s*(const\s+)?RoundedRectangleBorder\([^)]*\),?/g, '');
        newArgs = newArgs.replace(/shape:\s*(const\s+)?[^,]+AppRadius\.[a-z]+[^,]*,?/g, '');
        return `${btnType}.styleFrom(${newArgs})`;
    });

    // 2. InkWell without borderRadius -> inject it
    let index = 0;
    while ((index = content.indexOf('InkWell(', index)) !== -1) {
        let openParenCount = 1;
        let i = index + 'InkWell('.length;
        let start = i;
        
        while (i < content.length && openParenCount > 0) {
            if (content[i] === '(') openParenCount++;
            if (content[i] === ')') openParenCount--;
            i++;
        }
        
        let inkWellBody = content.substring(start, i - 1);
        
        // ONLY inject if it DOES NOT have borderRadius
        if (!inkWellBody.includes('borderRadius:')) {
            content = content.substring(0, start) + 'borderRadius: AppRadius.button, ' + content.substring(start);
            index = start + 'borderRadius: AppRadius.button, '.length;
        } else {
            // If it already has borderRadius, leave it alone to avoid syntax errors and layout issues!
            // The prompt says "preserve layout". Changing a list item's radius could break the card radius.
            index = i;
        }
    }

    if (content !== original) {
        if (content.includes('AppRadius.button') && !content.includes('app_radius.dart')) {
            let imports = content.match(/import\s+[^;]+;/g);
            if (imports && imports.length > 0) {
                let lastImport = imports[imports.length - 1];
                let lastImportIndex = content.lastIndexOf(lastImport) + lastImport.length;
                content = content.substring(0, lastImportIndex) + "\nimport 'package:stayhub_mobile/theme/app_radius.dart';" + content.substring(lastImportIndex);
            } else {
                content = "import 'package:stayhub_mobile/theme/app_radius.dart';\n" + content;
            }
        }
        fs.writeFileSync(filePath, content, 'utf8');
        console.log(`Updated ${filePath}`);
    }
}

walkDir('lib/screens', processFile);
