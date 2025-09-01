const fs = require('fs');
const path = require('path');
const readline = require('readline');
const os = require('os');
const Wallet = require('ethereumjs-wallet').default;

// Setup readline interface
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Promisified question
const ask = (question) => {
    return new Promise((resolve) => {
        rl.question(question, (answer) => resolve(answer));
    });
};

// Detect node folders
function detectNodes(baseDir) {
    const nodes = [];

    // First check if ~/node exists (single-node setup)
    const singleNodePath = path.join(baseDir, 'node');
    if (fs.existsSync(path.join(singleNodePath, 'data', 'keystore'))) {
        nodes.push({
            name: 'node',
            keystorePath: path.join(singleNodePath, 'data', 'keystore'),
            passwordPath: path.join(singleNodePath, 'password.txt')
        });
        return nodes;
    }

    // Else, check for multi-node folders (node1, node2, ...)
    const files = fs.readdirSync(baseDir);
    files.forEach((file) => {
        const fullPath = path.join(baseDir, file);
        if (
            fs.statSync(fullPath).isDirectory() &&
            /^node\d+$/.test(file) &&
            fs.existsSync(path.join(fullPath, 'data', 'keystore'))
        ) {
            nodes.push({
                name: file,
                keystorePath: path.join(fullPath, 'data', 'keystore'),
                passwordPath: path.join(fullPath, 'password.txt')
            });
        }
    });

    return nodes;
}

(async () => {
    try {
        const homeDir = os.homedir();
        const nodes = detectNodes(homeDir);

        if (nodes.length === 0) {
            console.error('❌ No valid nodes found (with data/keystore directories).');
            rl.close();
            return;
        }

        let selectedNode;

        if (nodes.length === 1) {
            selectedNode = nodes[0];
            console.log(`✅ Single node detected: ${selectedNode.name}`);
        } else {
            // Show options for multiple nodes
            console.log('✅ Detected nodes:');
            nodes.forEach((node, index) => {
                console.log(`  [${index + 1}] ${node.name}`);
            });

            const choice = await ask(`\nSelect a node to decrypt (1-${nodes.length}): `);
            const index = parseInt(choice, 10) - 1;

            if (isNaN(index) || index < 0 || index >= nodes.length) {
                console.error('❌ Invalid selection.');
                rl.close();
                return;
            }

            selectedNode = nodes[index];
        }

        // Load the keystore file
        const keystoreFiles = fs.readdirSync(selectedNode.keystorePath).filter(f => f.startsWith('UTC--'));
        if (keystoreFiles.length === 0) {
            throw new Error('No keystore file found in the selected node.');
        }

        const keystoreFilePath = path.join(selectedNode.keystorePath, keystoreFiles[0]);
        const passwordFilePath = selectedNode.passwordPath;

        if (!fs.existsSync(passwordFilePath)) {
            throw new Error(`Password file not found: ${passwordFilePath}`);
        }

        const keystoreContent = fs.readFileSync(keystoreFilePath, 'utf8');
        const password = fs.readFileSync(passwordFilePath, 'utf8').trim();
        const keystore = JSON.parse(keystoreContent);

        const wallet = await Wallet.fromV3(keystore, password);
        const privateKey = wallet.getPrivateKey().toString('hex');

        console.log(`\n🔐 Private key for ${selectedNode.name}:`);
        console.log(privateKey); // ⚠️ Be cautious with this output

        // Clear memory and screen after 1 minute
        setTimeout(() => {
            console.log('\n🧹 Flushing memory...');
            console.clear();
        }, 60000);

    } catch (err) {
        console.error('\n❌ Error:', err.message || err);
    } finally {
        rl.close();
    }
})();
