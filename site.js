(function () {
  "use strict";
  const demoPath = "exports/local/web/WineVR.html";
  const dialog = document.getElementById("demo-dialog");
  const frame = document.getElementById("demo-frame");
  const launchButton = document.getElementById("launch-demo");
  const closeButton = document.getElementById("close-demo");
  const fullscreenButton = document.getElementById("fullscreen-demo");
  const reloadButton = document.getElementById("reload-demo");
  const retryButton = document.getElementById("retry-demo");
  const launchState = document.getElementById("launch-state");
  const stateTitle = document.getElementById("launch-state-title");
  const stateMessage = document.getElementById("launch-state-message");
  const spinner = document.getElementById("loading-ring");
  const runtimeStatus = document.getElementById("runtime-status");
  let requestId = 0;
  let controller = null;
  let timeoutId = null;
  let lastFocus = null;
  let wasBodyOverflow = "";

  document.querySelectorAll(".preview-image img").forEach(function (image) {
    function unavailable() {
      image.hidden = true;
      image.parentElement.classList.add("is-unavailable");
    }
    image.addEventListener("error", unavailable);
    if (image.complete && image.naturalWidth === 0) unavailable();
  });

  function showState(title, message, error) {
    launchState.hidden = false;
    launchState.classList.toggle("is-error", Boolean(error));
    stateTitle.textContent = title;
    stateMessage.textContent = message;
    spinner.hidden = Boolean(error);
    retryButton.hidden = !error;
    runtimeStatus.textContent = error ? "Η εμπειρία δεν άνοιξε." : "Προετοιμασία της εμπειρίας…";
  }

  function stopPending() {
    requestId += 1;
    if (controller) controller.abort();
    controller = null;
    window.clearTimeout(timeoutId);
    timeoutId = null;
    frame.onload = null;
    frame.onerror = null;
  }

  async function loadDemo() {
    stopPending();
    const currentRequest = requestId;
    frame.src = "about:blank";
    showState("Η διαδρομή σου ξεκινά.", "Ελέγχουμε ότι η εμπειρία είναι διαθέσιμη.", false);
    reloadButton.disabled = true;
    if (window.location.protocol === "file:") {
      showState("Χρειάζεται διεύθυνση ιστοσελίδας.", "Άνοιξε το Grapes of Crete από μια τοπική ή ασφαλή web διεύθυνση. Η απευθείας εκκίνηση από αρχείο δεν μπορεί να φορτώσει το παιχνίδι.", true);
      reloadButton.disabled = false;
      return;
    }
    controller = new AbortController();
    const preflightTimeout = window.setTimeout(function () { if (currentRequest === requestId && controller) controller.abort(); }, 12000);
    try {
      const response = await fetch(demoPath, { cache: "no-store", signal: controller.signal, credentials: "same-origin" });
      if (!response.ok) throw new Error(response.status === 404 ? "missing-build" : "server-error");
      const documentText = await response.text();
      // A static host may return its landing page with HTTP 200 for missing paths.
      if (!/\bnew\s+Engine\s*\(/.test(documentText)) throw new Error("missing-build");
      if (currentRequest !== requestId || !dialog.open) return;
      window.clearTimeout(preflightTimeout);
      stateMessage.textContent = "Φορτώνουμε τον τρισδιάστατο κόσμο. Η πρώτη επίσκεψη μπορεί να χρειαστεί λίγο περισσότερο χρόνο.";
      runtimeStatus.textContent = "Φόρτωση Grapes of Crete…";
      frame.onload = function () {
        if (currentRequest !== requestId || !dialog.open || frame.getAttribute("src") === "about:blank") return;
        // An earlier about:blank navigation can finish after the real URL was set.
        // Only dismiss our loading state for the same-origin exported document.
        try {
          if (new URL(frame.contentWindow.location.href).pathname !== new URL(demoPath, window.location.href).pathname) return;
        } catch (_error) { return; }
        window.clearTimeout(timeoutId);
        timeoutId = null;
        launchState.hidden = true;
        runtimeStatus.textContent = "Η φόρτωση και οι επιλογές συνεχίζονται μέσα στην εφαρμογή.";
        reloadButton.disabled = false;
      };
      frame.onerror = function () {
        if (currentRequest !== requestId || !dialog.open) return;
        showState("Δεν ολοκληρώθηκε η φόρτωση.", "Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά. Μπορείς επίσης να ανοίξεις την εμπειρία σε ξεχωριστή καρτέλα.", true);
        reloadButton.disabled = false;
      };
      frame.src = demoPath;
      timeoutId = window.setTimeout(function () {
        if (currentRequest !== requestId || !dialog.open) return;
        showState("Η φόρτωση αργεί περισσότερο.", "Το αρχείο της εμπειρίας μπορεί να είναι μεγάλο. Δοκίμασε ξανά ή άνοιξέ το σε νέα καρτέλα από την επάνω μπάρα.", true);
        reloadButton.disabled = false;
      }, 30000);
    } catch (error) {
      if (currentRequest !== requestId || !dialog.open) return;
      const missing = error.message === "missing-build";
      showState(missing ? "Η web έκδοση δεν είναι διαθέσιμη εδώ ακόμη." : "Δεν μπορέσαμε να συνδεθούμε.", missing ? "Μπορείς να κλείσεις αυτό το παράθυρο και να γνωρίσεις τη διαδρομή από τις εικόνες. Δοκίμασε ξανά όταν η εμπειρία γίνει διαθέσιμη." : "Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά. Η περιγραφή και οι εικόνες της διαδρομής παραμένουν διαθέσιμες.", true);
      reloadButton.disabled = false;
    } finally {
      window.clearTimeout(preflightTimeout);
    }
  }

  function openDemo() {
    if (dialog.open) return;
    lastFocus = document.activeElement;
    wasBodyOverflow = document.body.style.overflow;
    dialog.showModal();
    document.body.style.overflow = "hidden";
    closeButton.focus();
    loadDemo();
  }

  function closeDemo() {
    if (!dialog.open) return;
    stopPending();
    frame.src = "about:blank";
    if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen().catch(function () {});
    dialog.close();
    document.body.style.overflow = wasBodyOverflow;
    if (lastFocus && typeof lastFocus.focus === "function") lastFocus.focus();
    else launchButton.focus();
  }

  async function toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (dialog.requestFullscreen) await dialog.requestFullscreen();
      else runtimeStatus.textContent = "Η πλήρης οθόνη δεν είναι διαθέσιμη εδώ. Μπορείς να ανοίξεις νέα καρτέλα.";
    } catch (_error) {
      runtimeStatus.textContent = "Ο browser δεν επέτρεψε πλήρη οθόνη. Η περιήγηση συνεχίζεται κανονικά.";
    }
  }

  function setCapability(id, text, available) {
    const element = document.getElementById(id);
    element.textContent = text;
    element.classList.toggle("available", Boolean(available));
  }

  async function inspectCapabilities() {
    try {
      const canvas = document.createElement("canvas");
      const context = canvas.getContext("webgl2", { failIfMajorPerformanceCaveat: true });
      setCapability("screen-status", context ? "WebGL 2 διαθέσιμο" : "Δεν εντοπίστηκε WebGL 2", Boolean(context));
      if (context) {
        const extension = context.getExtension("WEBGL_lose_context");
        if (extension) extension.loseContext();
      }
    } catch (_error) {
      setCapability("screen-status", "Δεν ολοκληρώθηκε ο έλεγχος", false);
    }
    if (!window.isSecureContext) {
      setCapability("vr-status", "Χρειάζεται HTTPS", false);
      setCapability("ar-status", "Χρειάζεται HTTPS", false);
      return;
    }
    if (!navigator.xr || typeof navigator.xr.isSessionSupported !== "function") {
      setCapability("vr-status", "Δεν προσφέρεται WebXR", false);
      setCapability("ar-status", "Δεν προσφέρεται WebXR", false);
      return;
    }
    await Promise.all([
      ["immersive-vr", "vr-status"],
      ["immersive-ar", "ar-status"]
    ].map(async function (entry) {
      try {
        const supported = await navigator.xr.isSessionSupported(entry[0]);
        setCapability(entry[1], supported ? "Αναφέρεται υποστήριξη" : "Δεν είναι διαθέσιμο", supported);
      } catch (_error) {
        setCapability(entry[1], "Ο έλεγχος δεν επιτράπηκε", false);
      }
    }));
  }

  launchButton.addEventListener("click", openDemo);
  closeButton.addEventListener("click", closeDemo);
  reloadButton.addEventListener("click", loadDemo);
  retryButton.addEventListener("click", loadDemo);
  fullscreenButton.addEventListener("click", toggleFullscreen);
  dialog.addEventListener("cancel", function (event) { event.preventDefault(); closeDemo(); });
  document.addEventListener("fullscreenchange", function () {
    fullscreenButton.textContent = document.fullscreenElement ? "Έξοδος πλήρους οθόνης" : "Πλήρης οθόνη";
  });
  window.addEventListener("pagehide", stopPending);
  inspectCapabilities();
})();
