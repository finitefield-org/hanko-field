(() => {
  document.body.addEventListener("htmx:responseError", (event) => {
    const detail = event.detail;
    if (!detail || !detail.xhr) {
      return;
    }

    const target = detail.target;
    if (!target || !(target instanceof HTMLElement)) {
      return;
    }

    if (detail.xhr.status >= 500) {
      target.insertAdjacentHTML(
        "afterbegin",
        "<p class=\"message-error\">サーバーエラーが発生しました。再度お試しください。</p>",
      );
    }
  });
})();
