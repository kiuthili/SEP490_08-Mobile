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
    // By using [\s\S]*? we match multiple lines carefully
    const buttonRegex = /(ElevatedButton|FilledButton|OutlinedButton|TextButton)\.styleFrom\s*\(([\s\S]*?)\)/g;
    
    content = content.replace(buttonRegex, (match, btnType, styleArgs) => {
        // We only want to remove `shape: ...` if it's there
        let newArgs = styleArgs.replace(/shape:\s*(const\s+)?RoundedRectangleBorder\([^)]*\),?/g, '');
        // Also remove if it's using AppRadius directly (e.g. AppRadius.xs)
        newArgs = newArgs.replace(/shape:\s*(const\s+)?[^,]+AppRadius\.[a-z]+[^,]*,?/g, '');
        
        // Return the reconstructed styleFrom
        return `${btnType}.styleFrom(${newArgs})`;
    });

    // 2. InkWell without borderRadius
    // Let's find InkWell( and inject borderRadius: AppRadius.button,
    // BUT only if it doesn't already have one inside its own parameter list
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
        
        if (!inkWellBody.includes('borderRadius:')) {
            content = content.substring(0, start) + 'borderRadius: AppRadius.button, ' + content.substring(start);
            index = start + 'borderRadius: AppRadius.button, '.length;
        } else {
            // It has borderRadius. Let's fix it if it's not AppRadius.button.
            // Replace `borderRadius: BorderRadius.circular(...)` with `borderRadius: AppRadius.button`
            // Replace `borderRadius: AppRadius.xs` with `borderRadius: AppRadius.button`
            let updatedBody = inkWellBody.replace(/borderRadius:\s*BorderRadius\.circular\([^)]*\),?/g, 'borderRadius: AppRadius.button,');
            updatedBody = updatedBody.replace(/borderRadius:\s*AppRadius\.[a-z]+,?/g, 'borderRadius: AppRadius.button,');
            content = content.substring(0, start) + updatedBody + content.substring(i - 1);
            index = start + updatedBody.length + 1;
        }
    }

    if (content !== original) {
        // Check if we need to import app_radius.dart
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
