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
        "<p class=\"m-4 rounded-xl border border-admin-alert/35 bg-[rgb(157_47_36_/_0.08)] px-3 py-2 text-sm font-semibold text-admin-alert\">サーバーエラーが発生しました。再度お試しください。</p>",
      );
    }
  });
})();
