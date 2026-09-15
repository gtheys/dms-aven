// StartupCheck.qml — gates plugin activation on the aven CLI being available.
// Pattern per DMS plugin docs: non-visual QtObject exposing check(done).
// done(null) allows activation; done({title, message}) blocks it.

import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("aven.depCheck", ["which", "aven"], function (stdout, exitCode) {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                title: "aven CLI not found",
                message: "The Aven Tasks plugin needs the aven CLI on PATH. Install it with:\n\n  curl -fsSL https://raw.githubusercontent.com/raine/aven/main/scripts/install | bash\n\nor: brew install raine/aven/aven\n\nThen reload this plugin (dms ipc call plugins reload aven)."
            });
        });
    }
}
