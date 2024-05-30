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
const keystoreContent = fs.readFileSync(keystoreFilePath, 'utf8');

// Read the password file
const password = fs.readFileSync(passwordFilePath, 'utf8').trim();

// Parse the keystore JSON
const keystore = JSON.parse(keystoreContent);

// Decrypt the keystore
Wallet.fromV3(keystore, password).then(wallet => {
    // Extract the private key
    const privateKey = wallet.getPrivateKey().toString('hex');
    console.log('Private Key:', privateKey);
}).catch(error => {
    console.error('Error decrypting keystore:', error);
});
