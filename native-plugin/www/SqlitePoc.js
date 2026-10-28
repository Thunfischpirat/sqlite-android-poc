const exec = require('cordova/exec');
exports.run = (success, error) => exec(success, error, 'SqlitePoc', 'run', []);
