// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

import { EditorState, StateEffect } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { StreamLanguage } from "@codemirror/language"
import { scheme } from "@codemirror/legacy-modes/mode/scheme"

let Hooks = {};

function codeMirrorExtensions(editable) {
  return [
    basicSetup,
    StreamLanguage.define(scheme),
    EditorView.editable.of(editable),
    EditorView.theme({
      "&": {
        fontSize: "16px"
      }
    }),
  ]
}

Hooks.CodeMirror = {
  mounted() {
    this.initializeEditor();
    this.attachSubmitListener();
    if (this.active) console.log("mounted");
  },

  updated() {
    if (this.active) console.log("updated");
    this.attachSubmitListener();
  },

  disconnected() {
    if (this.active) console.log("disconnected");
  },

  reconnected() {
    if (this.active) console.log("reconnected");
    this.initializeEditor();
  },

  destroyed() {
    console.log("destroyed()");
    if (this.active) console.log("active destroyed");
    if (this.editor) {
      console.log("destroyed");
      this.editor.destroy();
    }
  },

  initializeEditor() {
    this.editor = new EditorView({
      state: EditorState.create({
        extensions: codeMirrorExtensions(true)
      }),
      parent: this.el
    });
    this.handleExampleSelected = (e) => {
      this.editor.dispatch({
        changes: { from: 0, to: this.editor.state.doc.length, insert: e.detail.content }
      });
    }
    window.addEventListener("phx:example_selected", this.handleExampleSelected);
  },

  attachSubmitListener() {
    const runButton = document.getElementById("run-button");
    if (runButton && runButton !== this.runButton) {
      this.handleRunButtonClick = () => {
        runButton.removeEventListener("click", this.handleRunButtonClick);
        window.removeEventListener("phx:example_selected", this.handleExampleSelected);
        document.getElementById("code-input").value = this.editor.state.doc.toString();

        this.editor.dispatch({
          effects: StateEffect.reconfigure.of(codeMirrorExtensions(false))
        });
      }
      this.runButton = runButton;
      runButton.addEventListener("click", this.handleRunButtonClick);
    }
  }
};

Hooks.KeepAlive = {
  mounted() {
    const minutes = this.el.dataset.minutes || 5;
    const millis = minutes * 60 * 1000;
    this.interval = setInterval(() => {
      this.pushEvent("keep_alive");
    }, millis);
  },

  destroyed() {
    clearInterval(this.interval);
  }
};

Hooks.Formless = {
  mounted() {
    this.el.addEventListener('change', event => {
      const eventName = this.el.dataset.event

      this.pushEvent(eventName, { value: event.target.value })
    })
  }
};

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

