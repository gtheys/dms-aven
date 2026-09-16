// StartupCheck.qml — gates plugin activation on the aven CLI being available.
//
// DMS sessions often run with a minimal PATH (systemd/quickshell user session)
// that does NOT include ~/.local/bin, even when the user's interactive shell
// finds aven there. So probe common install locations instead of trusting PATH.
//
// Pattern per DMS plugin docs: non-visual QtObject exposing check(done).
// done(null) allows activation; done({title, message}) blocks it.

import QtQuick
import Quickshell
import qs.Common

QtObject {
    id: root

    // First entry honours PATH; the rest cover the usual install locations.
    property var candidates: [
        "aven",
        Quickshell.env("HOME") + "/.local/bin/aven",
        Quickshell.env("HOME") + "/.cargo/bin/aven",
        Quickshell.env("HOME") + "/bin/aven",
        "/usr/local/bin/aven",
        "/usr/bin/aven",
        "/opt/homebrew/bin/aven"
    ]

    function check(done) {
        var i = 0;
        function tryNext() {
            if (i >= root.candidates.length) {
                done({
                    title: "aven CLI not found",
                    message: "The Aven Tasks plugin could not find the aven CLI on PATH or in ~/.local/bin.\n\nInstall it:\n\n  curl -fsSL https://raw.githubusercontent.com/raine/aven/main/scripts/install | bash\n\nIf aven lives somewhere else, set the full path in DMS Settings \u2192 Plugins \u2192 Aven Tasks \u2192 \u201Caven binary\u201D, then reload the plugin (dms ipc call plugins reload aven)."
                });
                return;
            }
            var candidate = root.candidates[i++];
            var args = candidate.indexOf("/") === 0
                ? ["test", "-x", candidate]
                : ["which", candidate];
            Proc.runCommand("aven.depCheck", args, function (stdout, exitCode) {
                if (exitCode === 0) {
                    done(null);
                    return;
                }
                tryNext();
            });
        }
        tryNext();
    }
}
