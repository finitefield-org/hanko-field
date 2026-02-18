(() => {
  const getUploadContext = (sourceElement) => {
    if (!(sourceElement instanceof Element)) {
      return null;
    }
    const form = sourceElement.closest("form");
    if (!(form instanceof HTMLFormElement)) {
      return null;
    }

    return {
      form,
      fileInput: form.querySelector("[data-photo-file-input]"),
      statusElement: form.querySelector("[data-photo-upload-status]"),
      pathInput: form.querySelector('input[name="photo_storage_path"]'),
      keyInput:
        form.querySelector('input[name="material_key"]') ||
        form.querySelector('input[name="key"]'),
      uploadButton: form.querySelector("[data-photo-upload-button]"),
      previewWrap: form.querySelector("[data-photo-preview-wrap]"),
      previewImage: form.querySelector("[data-photo-preview]"),
    };
  };

  const setUploadStatus = (statusElement, message, isError) => {
    if (!(statusElement instanceof HTMLElement)) {
      if (isError && message) {
        window.alert(message);
      }
      return;
    }
    statusElement.textContent = message;
    statusElement.classList.remove(
      "text-admin-muted",
      "text-admin-alert",
      "text-admin-accent",
    );
    if (isError) {
      statusElement.classList.add("text-admin-alert");
    } else if (message) {
      statusElement.classList.add("text-admin-accent");
    } else {
      statusElement.classList.add("text-admin-muted");
    }
  };

  const setPreviewVisible = (previewWrap, previewImage, src) => {
    if (
      !(previewWrap instanceof HTMLElement) ||
      !(previewImage instanceof HTMLImageElement)
    ) {
      return;
    }
    if (src) {
      previewImage.src = src;
      previewWrap.classList.remove("hidden");
      return;
    }
    previewImage.removeAttribute("src");
    previewWrap.classList.add("hidden");
  };

  const revokePreviewObjectUrl = (previewImage) => {
    if (!(previewImage instanceof HTMLImageElement)) {
      return;
    }
    const previous = previewImage.dataset.objectUrl;
    if (previous) {
      URL.revokeObjectURL(previous);
      delete previewImage.dataset.objectUrl;
    }
  };

  const setStoragePath = (pathInput, storagePath) => {
    if (!(pathInput instanceof HTMLInputElement)) {
      return;
    }
    pathInput.value = storagePath;
    pathInput.dispatchEvent(new Event("input", { bubbles: true }));
    pathInput.dispatchEvent(new Event("change", { bubbles: true }));
  };

  const isSupportedImageFile = (file) => {
    if (!(file instanceof File)) {
      return false;
    }
    if (file.type.startsWith("image/")) {
      return true;
    }

    return /\.(png|jpe?g|webp|gif|avif)$/i.test(file.name);
  };

  const updatePreviewFromFileInput = (fileInput) => {
    if (!(fileInput instanceof HTMLInputElement)) {
      return;
    }
    const context = getUploadContext(fileInput);
    if (!context) {
      return;
    }

    const { previewWrap, previewImage } = context;
    if (
      !(previewWrap instanceof HTMLElement) ||
      !(previewImage instanceof HTMLImageElement)
    ) {
      return;
    }

    const file = fileInput.files && fileInput.files[0];
    if (!file) {
      revokePreviewObjectUrl(previewImage);
      setPreviewVisible(previewWrap, previewImage, "");
      return;
    }
    if (!isSupportedImageFile(file)) {
      revokePreviewObjectUrl(previewImage);
      setPreviewVisible(previewWrap, previewImage, "");
      return;
    }

    revokePreviewObjectUrl(previewImage);
    const objectUrl = URL.createObjectURL(file);
    previewImage.dataset.objectUrl = objectUrl;
    setPreviewVisible(previewWrap, previewImage, objectUrl);
  };

  const resolveMaterialKey = (form, keyInput) => {
    if (keyInput instanceof HTMLInputElement) {
      const value = keyInput.value.trim();
      if (value) {
        return value;
      }
    }

    const action =
      form.getAttribute("hx-patch") ||
      form.getAttribute("hx-post") ||
      form.getAttribute("action") ||
      "";
    const match = action.match(/\/admin\/materials\/([^/]+)/);
    if (match && match[1]) {
      return decodeURIComponent(match[1]);
    }
    return "";
  };

  const uploadMaterialPhoto = async (sourceElement, options = {}) => {
    if (!(sourceElement instanceof Element)) {
      return;
    }

    const { silentMissingKey = false } = options;
    const context = getUploadContext(sourceElement);
    if (!context) {
      return;
    }

    const {
      form,
      fileInput,
      statusElement,
      pathInput,
      keyInput,
      uploadButton,
    } = context;

    if (
      !(fileInput instanceof HTMLInputElement) ||
      !fileInput.files ||
      fileInput.files.length === 0
    ) {
      setUploadStatus(statusElement, "画像ファイルを選択してください。", true);
      return;
    }
    if (!(pathInput instanceof HTMLInputElement)) {
      setUploadStatus(
        statusElement,
        "Storage パス入力欄が見つかりません。",
        true,
      );
      return;
    }

    const materialKey = resolveMaterialKey(form, keyInput);
    if (!materialKey) {
      if (silentMissingKey) {
        setUploadStatus(
          statusElement,
          "材質キーを入力すると Storage パスを自動入力します。",
          false,
        );
      } else {
        setUploadStatus(statusElement, "材質キーを入力してください。", true);
      }
      return;
    }

    const file = fileInput.files[0];
    if (!isSupportedImageFile(file)) {
      setUploadStatus(
        statusElement,
        "画像ファイル（png/jpg/webp/gif/avif）を選択してください。",
        true,
      );
      return;
    }

    if (form.dataset.photoUploadInFlight === "1") {
      return;
    }

    const formData = new FormData();
    formData.append("material_key", materialKey);
    formData.append("photo_file", file, file.name);

    form.dataset.photoUploadInFlight = "1";
    if (uploadButton instanceof HTMLButtonElement) {
      uploadButton.disabled = true;
    }
    setUploadStatus(statusElement, "アップロード中...", false);

    try {
      const response = await fetch("/admin/materials/photo-upload", {
        method: "POST",
        body: formData,
      });

      let payload = {};
      let fallbackMessage = "";
      const rawText = await response.text();
      if (rawText) {
        try {
          payload = JSON.parse(rawText);
        } catch (_) {
          fallbackMessage = rawText;
        }
      }

      if (!response.ok) {
        const message =
          typeof payload.error === "string" && payload.error
            ? payload.error
            : fallbackMessage || "アップロードに失敗しました。";
        throw new Error(message);
      }

      if (typeof payload.storage_path !== "string" || !payload.storage_path) {
        throw new Error("Storage パスを取得できませんでした。");
      }

      setStoragePath(pathInput, payload.storage_path);
      setUploadStatus(
        statusElement,
        `アップロード完了: ${payload.storage_path}`,
        false,
      );
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "アップロードに失敗しました。";
      setUploadStatus(statusElement, message, true);
    } finally {
      delete form.dataset.photoUploadInFlight;
      if (uploadButton instanceof HTMLButtonElement) {
        uploadButton.disabled = false;
      }
    }
  };

  document.body.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    const button = target.closest("[data-photo-upload-button]");
    if (!button) {
      return;
    }

    event.preventDefault();
    uploadMaterialPhoto(button);
  });

  document.body.addEventListener("change", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    const fileInput = target.closest("[data-photo-file-input]");
    if (!(fileInput instanceof HTMLInputElement)) {
      return;
    }
    updatePreviewFromFileInput(fileInput);
    uploadMaterialPhoto(fileInput, { silentMissingKey: true });
  });

  document.body.addEventListener("change", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    const keyInput = target.closest(
      'input[name="key"], input[name="material_key"]',
    );
    if (!(keyInput instanceof HTMLInputElement)) {
      return;
    }

    const form = keyInput.closest("form");
    if (!(form instanceof HTMLFormElement)) {
      return;
    }

    const fileInput = form.querySelector("[data-photo-file-input]");
    if (!(fileInput instanceof HTMLInputElement)) {
      return;
    }

    if (!fileInput.files || fileInput.files.length === 0) {
      return;
    }

    uploadMaterialPhoto(fileInput, { silentMissingKey: true });
  });

  window.addEventListener("beforeunload", () => {
    const previews = document.querySelectorAll("[data-photo-preview]");
    for (const preview of previews) {
      if (preview instanceof HTMLImageElement) {
        revokePreviewObjectUrl(preview);
      }
    }
  });

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
