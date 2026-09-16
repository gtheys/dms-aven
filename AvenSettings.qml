// AvenSettings.qml — settings pane for the Aven launcher plugin.

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "aven"

    StyledText {
        width: parent.width
        text: "Aven Tasks"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Add tasks to your aven todo manager from DankLauncher. Type the trigger, then a task title. Results let you pick the project — or create a new one."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "avenBin"
        label: "aven binary"
        description: "Name or full path of the aven CLI. A bare name is auto-resolved to an absolute path (PATH, ~/.local/bin, ~/.cargo/bin, ~/bin, /usr/local/bin, /usr/bin) because the DMS session often has a minimal PATH."
        placeholder: "aven"
        defaultValue: "aven"
    }

    StringSetting {
        settingKey: "trigger"
        label: "Launcher trigger"
        description: "Prefix typed in DankLauncher to activate this plugin. Applied after reload."
        placeholder: "av"
        defaultValue: "av"
        onValueChanged: {
            if (!pluginService)
                return;
            // Persist to the data store the launcher object reads on load.
            pluginService.savePluginData("aven", "trigger", value);
        }
    }

    StringSetting {
        settingKey: "defaultWorkspace"
        label: "Default workspace"
        description: "Optional aven workspace to target (passed as --workspace). Leave empty to let aven infer it."
        placeholder: "(infer from directory)"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "showInboxOption"
        label: "Offer \u201CAdd to Inbox\u201D"
        description: "Always show an option to add the task without a project"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showCreateOption"
        label: "Offer project creation"
        description: "Show \u201CCreate project \u2026 and add task\u201D when no project matches"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Usage:  \u201Cav buy milk\u201D lists your projects \u2022 \u201Cav buy milk @home\u201D targets a project directly \u2022 an @name with no match offers to create it."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
