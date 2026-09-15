// AvenLauncher.qml — DMS launcher plugin for the aven task manager.
//
// Flow: type `av <task title>` in DankLauncher, get your aven projects back as
// selectable results. Enter adds the task to the highlighted project.
// "Add to Inbox (no project)" and "Create new project..." are always offered.
//
// Syntax:
//   av <title>                  -> project picker + inbox option
//   av <title> @<project>       -> direct-add to matching project(s)
//   av <title> @<newname>       -> if no project matches, offers project creation
//
// Everything goes through the `aven` CLI (verified against aven 0.1.x):
//   aven project list --json
//   aven add "Title" --project <key>
//   aven project create "Name"

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "aven"
    property string trigger: ""
    signal itemsChanged

    // ---- settings (pluginData-backed, saved via pluginService) -------------
    property string avenBin: "aven"
    property string defaultWorkspace: ""
    property bool showInboxOption: true
    property bool showCreateOption: true

    // The DMS session often has a minimal PATH without ~/.local/bin, so a bare
    // "aven" may not resolve even though the user's shell finds it. On load we
    // upgrade the setting to an absolute path by probing common locations.
    function resolveAvenBin() {
        var configured = avenBin;
        if (configured.indexOf("/") === 0) {
            // Already an absolute path — trust the user.
            return;
        }
        var home = Quickshell.env("HOME");
        var candidates = [
            configured,
            home + "/.local/bin/" + configured,
            home + "/bin/" + configured,
            "/usr/local/bin/" + configured,
            "/usr/bin/" + configured,
            "/opt/homebrew/bin/" + configured
        ];
        var i = 0;
        function tryNext() {
            if (i >= candidates.length)
                return; // keep bare name; startup check will surface the problem
            var candidate = candidates[i++];
            var args = candidate.indexOf("/") === 0
                ? ["test", "-x", candidate]
                : ["which", candidate];
            Proc.runCommand("aven.resolveBin", args, function (stdout, exitCode) {
                if (exitCode === 0 && candidate.indexOf("/") === 0) {
                    avenBin = candidate;
                    saveSetting("avenBinResolved", candidate);
                    return;
                }
                if (exitCode === 0 && stdout.trim().length > 0) {
                    avenBin = stdout.trim();
                    saveSetting("avenBinResolved", avenBin);
                    return;
                }
                tryNext();
            });
        }
        tryNext();
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        avenBin = pluginService.loadPluginData(pluginId, "avenBin", "aven");
        defaultWorkspace = pluginService.loadPluginData(pluginId, "defaultWorkspace", "");
        showInboxOption = pluginService.loadPluginData(pluginId, "showInboxOption", true);
        showCreateOption = pluginService.loadPluginData(pluginId, "showCreateOption", true);
        trigger = pluginService.loadPluginData(pluginId, "trigger", "av");
        resolveAvenBin();
    }

    function saveSetting(key, value) {
        if (pluginService)
            pluginService.savePluginData(pluginId, key, value);
    }

    // ---- pending task state ------------------------------------------------
    property string pendingTitle: ""
    property var pendingProjects: []
    property bool projectsLoaded: false
    property string lastError: ""

    // ---- helper: build arg list for the aven binary ------------------------
    function avenArgs(args) {
        var argv = [avenBin].concat(args);
        if (defaultWorkspace && defaultWorkspace.length > 0)
            argv.push("--workspace", defaultWorkspace);
        return argv;
    }

    // ---- project cache -----------------------------------------------------
    // Projects are cached briefly so getItems() stays synchronous; the cache is
    // refreshed async on every invocation.
    property var projectCache: []
    property real projectCacheAt: 0

    function refreshProjects() {
        Proc.runCommand("aven.listProjects", avenArgs(["project", "list", "--json"]), function (stdout, exitCode) {
            if (exitCode !== 0) {
                root.lastError = "aven project list failed (exit " + exitCode + ")";
                return;
            }
            root.applyProjectJson(stdout);
        });
    }

    function applyProjectJson(stdout) {
        var parsed = [];
        try {
            parsed = JSON.parse(stdout);
        } catch (e) {
            lastError = "Could not parse aven project list output";
            projectsLoaded = false;
            return;
        }
        var projects = [];
        for (var i = 0; i < parsed.length; i++) {
            projects.push({
                "key": parsed[i].key || parsed[i].name,
                "name": parsed[i].name || parsed[i].key,
                "prefix": parsed[i].prefix || ""
            });
        }
        projectCache = projects;
        projectCacheAt = Date.now();
        projectsLoaded = true;
        lastError = "";
    }

    // ---- title/@project parsing --------------------------------------------
    // Splits "buy milk @home gym" into title="buy milk", projectQuery="home gym"
    // (everything after the first @). Returns {title, projectQuery}.
    function parseQuery(query) {
        var q = query.trim();
        var at = q.indexOf("@");
        if (at < 0)
            return { "title": q, "projectQuery": "" };
        return {
            "title": q.substring(0, at).trim(),
            "projectQuery": q.substring(at + 1).trim().toLowerCase()
        };
    }

    function filterProjects(projectQuery) {
        if (!projectQuery || projectQuery.length === 0)
            return projectCache;
        var out = [];
        for (var i = 0; i < projectCache.length; i++) {
            var p = projectCache[i];
            var k = p.key.toLowerCase();
            var n = p.name.toLowerCase();
            var f = p.prefix.toLowerCase();
            if (k.indexOf(projectQuery) >= 0 || n.indexOf(projectQuery) >= 0 || f.indexOf(projectQuery) >= 0)
                out.push(p);
        }
        return out;
    }

    // ---- getItems: required by DMS launcher plugins -------------------------
    function getItems(query) {
        var trimmed = query.trim();
        if (trimmed.length === 0)
            return [];

        refreshProjects(); // keep cache warm; results below use the last good cache

        var parsed = parseQuery(trimmed);
        var title = parsed.title;
        if (title.length === 0) {
            // Just "av" or "av @" typed: show hint items.
            var hints = [];
            hints.push(makeHintItem("Type a task title", "av buy milk @project — pick where it lands", "edit"));
            if (projectCache.length > 0)
                hints.push(makeHintItem("Projects (" + projectCache.length + ")", projectCache.map(function (p) { return p.name; }).join(", "), "folder_open"));
            else if (!projectsLoaded)
                hints.push(makeHintItem("Loading projects…", "Run `aven` once to make sure it works", "hourglass_empty"));
            return hints;
        }

        var matches = filterProjects(parsed.projectQuery);
        var items = [];

        if (parsed.projectQuery.length > 0 && matches.length === 1) {
            // Unambiguous project: direct-add item first.
            items.push(makeAddItem(title, matches[0]));
        } else if (parsed.projectQuery.length > 0 && matches.length === 0) {
            // No project matches: offer to create it.
            if (showCreateOption)
                items.push(makeCreateItem(parsed.projectQuery, title));
        } else {
            // No @ filter (or ambiguous matches): one add-item per project.
            for (var i = 0; i < matches.length; i++)
                items.push(makeAddItem(title, matches[i]));
        }

        if (showInboxOption && parsed.projectQuery.length === 0)
            items.push(makeInboxItem(title));

        // Never leave the user without a way out.
        if (items.length === 0)
            items.push(makeInboxItem(title));
        if (showCreateOption && parsed.projectQuery.length === 0)
            items.push(makeHintItem("\u201C@name\u201D picks a project directly", "No match? aven will offer to create it", "lightbulb"));

        return items;
    }

    // Action payload format: "verb:arg1:rest-of-string-is-title".
    // aven project keys are slugs (no colons), so splitting on the first
    // colons is safe; the title keeps any colons it has.
    function makeAddItem(title, project) {
        return {
            name: "Add to " + project.name,
            icon: "material:task_alt",
            comment: "aven add \u201C" + title + "\u201D \u2192 " + (project.prefix ? project.prefix + " " : "") + project.key,
            action: "custom:add:" + project.key + ":" + title,
            categories: ["Aven"],
            keywords: ["aven", "todo", "task", project.key, project.name]
        };
    }

    function makeCreateItem(projectName, title) {
        return {
            name: "Create project \u201C" + projectName + "\u201D and add task",
            icon: "material:playlist_add",
            comment: "No existing project matches \u201C@" + projectName + "\u201D",
            action: "custom:create:" + projectName + ":" + title,
            categories: ["Aven"],
            keywords: ["aven", "todo", "task", "create project"]
        };
    }

    function makeInboxItem(title) {
        return {
            name: "Add to Inbox (no project)",
            icon: "material:inbox",
            comment: "aven add \u201C" + title + "\u201D — triage later in the aven TUI",
            action: "custom:inbox:" + title,
            categories: ["Aven"],
            keywords: ["aven", "todo", "task", "inbox"]
        };
    }

    function makeHintItem(name, comment, icon) {
        return {
            name: name,
            icon: "material:" + icon,
            comment: comment,
            action: "custom:none:",
            categories: ["Aven"],
            keywords: []
        };
    }

    // ---- executeItem: required by DMS launcher plugins ----------------------
    function executeItem(item) {
        if (!item || !item.action || item.action.indexOf("custom:") !== 0)
            return;
        // Payload: "custom:<verb>:<arg>:<title...>" (inbox has no arg).
        var payload = item.action.substring("custom:".length);
        var firstColon = payload.indexOf(":");
        var verb = firstColon >= 0 ? payload.substring(0, firstColon) : payload;
        var rest = firstColon >= 0 ? payload.substring(firstColon + 1) : "";

        if (verb === "add") {
            var argColon = rest.indexOf(":");
            var projectKey = argColon >= 0 ? rest.substring(0, argColon) : rest;
            var title = argColon >= 0 ? rest.substring(argColon + 1) : "";
            if (projectKey.length === 0 || title.length === 0)
                return;
            runAven(["add", title, "--project", projectKey],
                    "Added \u201C" + title + "\u201D to " + projectKey);
        } else if (verb === "inbox") {
            if (rest.length === 0)
                return;
            runAven(["add", rest], "Added \u201C" + rest + "\u201D to inbox");
        } else if (verb === "create") {
            var cArg = rest.indexOf(":");
            var newProject = cArg >= 0 ? rest.substring(0, cArg) : rest;
            var t2 = cArg >= 0 ? rest.substring(cArg + 1) : "";
            if (newProject.length === 0 || t2.length === 0)
                return;
            createProjectThenAdd(newProject, t2);
        }
        // "none": hint item, do nothing.
    }

    // ---- command execution ---------------------------------------------------
    // AIDEV-NOTE: root must stay a bare QtObject (DMS launcher plugin contract),
    // and QtObject has no default property — declaring Process/Timer/Component
    // children fails at load with "Cannot assign to non-existent default
    // property". All process spawning goes through the Proc service instead.
    // Proc gives no stderr, so error toasts only carry the exit code.
    function runAven(argv, successMsg) {
        Proc.runCommand(null, avenArgs(argv), function (stdout, exitCode) {
            if (exitCode === 0) {
                var ref = stdout.trim().split("\n")[0];
                ToastService.showInfo("Aven", successMsg + (ref ? " (" + ref + ")" : ""));
            } else {
                ToastService.showError("Aven", "aven failed (exit " + exitCode + ")");
            }
        });
    }

    function createProjectThenAdd(name, title) {
        Proc.runCommand(null, avenArgs(["project", "create", name]), function (stdout, exitCode) {
            if (exitCode === 0) {
                root.runAven(["add", title, "--project", name], "Added \u201C" + title + "\u201D to new project " + name);
            } else {
                ToastService.showError("Aven", "aven project create failed (exit " + exitCode + ")");
            }
        });
    }
}
