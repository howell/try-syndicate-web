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

import {EditorState} from "@codemirror/state";
import {EditorView, basicSetup} from "codemirror";
import {StreamLanguage} from "@codemirror/language"
import {scheme} from "@codemirror/legacy-modes/mode/scheme"

let Hooks = {};

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
    const code = this.el.dataset.code || "";
    this.active = this.el.dataset.active === "true";

    this.editor = new EditorView({
      state: EditorState.create({
        doc: code,
        extensions: [basicSetup, StreamLanguage.define(scheme), EditorView.editable.of(this.active)]
      }),
      parent: this.el
    });
    if (this.active) {
      window.addEventListener("phx:example_selected", (e) => {
        this.editor.dispatch({
          changes: { from: 0, to: this.editor.state.doc.length, insert: e.detail.content }
        });
      });
    }
  },

  attachSubmitListener() {
    if (this.active) {
      const runButton = document.getElementById("run-button");
      if (runButton && runButton !== this.runButton) {
        this.runButton = runButton;
        runButton.addEventListener("click", () => {
          document.getElementById("code-input").value = this.editor.state.doc.toString();
          this.editor.dispatch({
            changes: { from: 0, to: this.editor.state.doc.length, insert: "" }
          });
        });
      }
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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

