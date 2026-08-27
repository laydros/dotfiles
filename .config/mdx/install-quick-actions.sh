#!/usr/bin/env bash
#
# Builds Finder Quick Actions that run mdx, one per output format.
#
# Each one lands in ~/Library/Services. Installing them is not enough to make
# them usable - see the steps printed at the end. Re-run this after changing
# the command below; the bundles are generated, not hand-edited.

set -euo pipefail

# Overridable so the generated bundles can be inspected without disturbing
# the installed ones, whose enabled state lives outside the bundle.
services_dir="${MDX_SERVICES_DIR:-$HOME/Library/Services}"

# Which selections the Quick Actions offer themselves for. Restricting this to
# markdown keeps them out of the context menu for every other kind of file.
send_types='["net.daringfireball.markdown"]'
action_bundle="/System/Library/Automator/Run Shell Script.action"

command -v jq >/dev/null 2>&1 || {
  echo "install-quick-actions: jq is required" >&2
  exit 1
}

# Finder hands the selection in as arguments. A single file opens when it is
# done, since that is almost always a "look at it now" conversion; a batch
# stays quiet so a ten-file selection does not open ten windows. stderr goes
# to a log because a Quick Action has nowhere to print.
# The single quotes are deliberate: $@, $# and $HOME belong to the generated
# script, not to this one.
# shellcheck disable=SC2016
command_template='log=/tmp/mdx-quickaction.log

if [ "$#" -eq 1 ]; then
  set -- -O "$@"
fi

if ! "$HOME/bin/mdx" -t @FORMAT@ "$@" >/dev/null 2>"$log"; then
  osascript -e "display notification \"Conversion failed - see $log\" with title \"mdx\""
  exit 1
fi'

make_quick_action() {
  local format=$1 label=$2
  local bundle="$services_dir/$label.workflow"
  local contents="$bundle/Contents"
  local command_string

  command_string=${command_template//@FORMAT@/$format}

  rm -rf "$bundle"
  mkdir -p "$contents"

  jq -n --arg label "$label" --argjson send_types "$send_types" '{
    NSServices: [{
      NSBackgroundColorName: "background",
      NSIconName: "NSActionTemplate",
      NSMenuItem: { default: $label },
      NSMessage: "runWorkflowAsService",
      NSRequiredContext: { NSApplicationIdentifier: "com.apple.finder" },
      NSSendFileTypes: $send_types
    }]
  }' | plutil -convert xml1 -o "$contents/Info.plist" -

  jq -n \
    --arg cmd "$command_string" \
    --arg bundle_path "$action_bundle" \
    --arg input_uuid "$(uuidgen)" \
    --arg output_uuid "$(uuidgen)" \
    --arg action_uuid "$(uuidgen)" \
    '{
      AMApplicationBuild: "523",
      AMApplicationVersion: "2.10",
      AMDocumentVersion: "2",
      actions: [{
        action: {
          AMAccepts: {
            Container: "List",
            Optional: true,
            Types: ["com.apple.cocoa.string"]
          },
          AMActionVersion: "2.0.3",
          AMApplication: ["Automator"],
          AMParameterProperties: {
            COMMAND_STRING: {},
            CheckedForUserDefaultShell: {},
            inputMethod: {},
            shell: {},
            source: {}
          },
          AMProvides: {
            Container: "List",
            Types: ["com.apple.cocoa.string"]
          },
          ActionBundlePath: $bundle_path,
          ActionName: "Run Shell Script",
          ActionParameters: {
            COMMAND_STRING: $cmd,
            CheckedForUserDefaultShell: true,
            inputMethod: 1,
            shell: "/bin/bash",
            source: ""
          },
          BundleIdentifier: "com.apple.RunShellScript",
          CFBundleVersion: "2.0.3",
          CanShowSelectedItemsWhenRun: false,
          CanShowWhenRun: true,
          Category: ["AMCategoryUtilities"],
          "Class Name": "RunShellScriptAction",
          InputUUID: $input_uuid,
          Keywords: ["Shell", "Script", "Command", "Run", "Unix"],
          OutputUUID: $output_uuid,
          UUID: $action_uuid,
          UnlocalizedApplications: ["Automator"],
          conversionLabel: 0,
          isViewVisible: 1,
          location: "309.000000:253.000000",
          nibPath: ($bundle_path + "/Contents/Resources/Base.lproj/main.nib")
        },
        isViewVisible: 1
      }],
      connectors: {},
      workflowMetaData: {
        applicationBundleID: "com.apple.finder",
        applicationBundleIDsByPath: {
          "/System/Library/CoreServices/Finder.app": "com.apple.finder"
        },
        applicationPath: "/System/Library/CoreServices/Finder.app",
        applicationPaths: ["/System/Library/CoreServices/Finder.app"],
        inputTypeIdentifier: "com.apple.Automator.fileSystemObject",
        outputTypeIdentifier: "com.apple.Automator.nothing",
        presentationMode: 15,
        processesInput: false,
        serviceApplicationBundleID: "com.apple.finder",
        serviceApplicationPath: "/System/Library/CoreServices/Finder.app",
        serviceInputTypeIdentifier: "com.apple.Automator.fileSystemObject",
        serviceOutputTypeIdentifier: "com.apple.Automator.nothing",
        serviceProcessesInput: false,
        systemImageName: "NSActionTemplate",
        useAutomaticInputType: false,
        workflowTypeIdentifier: "com.apple.Automator.servicesMenu"
      }
    }' | plutil -convert xml1 -o "$contents/document.wflow" -

  echo "$bundle"
}

[ -d "$action_bundle" ] || {
  echo "install-quick-actions: missing $action_bundle" >&2
  exit 1
}

make_quick_action pdf "Convert Markdown to PDF"
make_quick_action html "Convert Markdown to HTML"
make_quick_action docx "Convert Markdown to Word"

/System/Library/CoreServices/pbs -flush 2>/dev/null || true

# Neither of these can be done from here. Finder caches the service list, so
# the actions are invisible everywhere - including System Settings - until it
# restarts. They then arrive switched off.
cat <<'NEXT'

Installed. Two manual steps remain:

  1. killall Finder
     Finder caches the service list; until it restarts the actions do not
     appear in the context menu or in System Settings.

  2. Switch them on under
     System Settings > General > Login Items & Extensions > Finder
     Newly installed Quick Actions arrive disabled.
NEXT
