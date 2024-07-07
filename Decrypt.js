const fs = require('fs');
const path = require('path');
const Wallet = require('ethereumjs-wallet').default;

// Directory containing the keystore file
const keystoreDir = path.join(process.env.HOME, 'node/data/keystore');

// Path to your password file
const passwordFilePath = path.join(process.env.HOME, 'node/password.txt');

// Filter out files and directories other than keystore files
const keystoreFiles = fs.readdirSync(keystoreDir).filter(file => file.startsWith('UTC--'));

// Check if there's at least one keystore file
if (keystoreFiles.length === 0) {
    throw new Error('No keystore file found in the directory.');
}

// Construct the path to the keystore file
const keystoreFileName = keystoreFiles[0];
const keystoreFilePath = path.join(keystoreDir, keystoreFileName);

// Read the keystore file
let keystoreContent = fs.readFileSync(keystoreFilePath, 'utf8');

// Read the password file
let password = fs.readFileSync(passwordFilePath, 'utf8').trim();

// Parse the keystore JSON
let keystore = JSON.parse(keystoreContent);

// Decrypt the keystore
Wallet.fromV3(keystore, password).then(wallet => {
    // Extract the private key
    let privateKey = wallet.getPrivateKey().toString('hex');
    console.log('Private Key:', privateKey);

    // Set a timeout to clear sensitive information and clear the screen after 2 minutes
    setTimeout(() => {
        console.log('Flushing memory...');
        keystoreContent = null;
        password = null;
        keystore = null;
        privateKey = null;
        console.log('Memory flushed.');
        console.clear();
    }, 60000); // 60000 milliseconds = 1 minute

}).catch(error => {
    console.error('Error decrypting keystore:', error);
});
