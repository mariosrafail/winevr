(function () {
  var demoPath = "web5/WineVR.html";
  var launchButton = document.getElementById("launch-demo");
  var overlay = document.getElementById("demo-overlay");
  var surface = document.getElementById("demo-surface");
  var frame = document.getElementById("demo-frame");
  var fullscreenButton = document.getElementById("fullscreen-demo");
  var reloadButton = document.getElementById("reload-demo");
  var closeButton = document.getElementById("close-demo");

  function openDemo() {
    overlay.classList.add("is-open");
    overlay.setAttribute("aria-hidden", "false");
    document.body.classList.add("modal-open");
    frame.src = demoPath;
    closeButton.focus();
  }

  function closeDemo() {
    if (document.fullscreenElement) {
      document.exitFullscreen().catch(function () {});
    }

    frame.removeAttribute("src");
    overlay.classList.remove("is-open");
    overlay.setAttribute("aria-hidden", "true");
    document.body.classList.remove("modal-open");
    launchButton.focus();
  }

  function reloadDemo() {
    frame.removeAttribute("src");
    window.requestAnimationFrame(function () {
      frame.src = demoPath;
    });
  }

  function toggleFullscreen() {
    if (document.fullscreenElement) {
      document.exitFullscreen().catch(function () {});
      return;
    }

    if (surface.requestFullscreen) {
      surface.requestFullscreen().catch(function () {});
    }
  }

  launchButton.addEventListener("click", openDemo);
  closeButton.addEventListener("click", closeDemo);
  reloadButton.addEventListener("click", reloadDemo);
  fullscreenButton.addEventListener("click", toggleFullscreen);

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && overlay.classList.contains("is-open")) {
      closeDemo();
    }
  });
})();
