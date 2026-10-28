const button = document.getElementById('run');
const output = document.getElementById('output');

function finish(message) {
    output.textContent = message;
    button.disabled = false;
}

function runDemo() {
    button.disabled = true;
    output.textContent = 'Creating, closing and reopening SQLite…';
    cordova.plugins.sqlitePoc.run(
        result => finish(result.message + ' — Database: ' + result.path),
        error => finish('Error: ' + error)
    );
}

document.addEventListener('deviceready', () => {
    button.disabled = false;
    output.textContent = 'Ready.';
    button.addEventListener('click', runDemo);
});
