(() => {
  const localeSelects = Array.from(document.querySelectorAll("[data-locale-select]"));
  const localeInput = document.getElementById("locale");
  const isEnglishLocale = (document.documentElement.lang || "")
    .trim()
    .toLowerCase()
    .startsWith("en");

  function parseLocale(raw) {
    const normalized = (raw || "").trim().toLowerCase();
    if (normalized.startsWith("ja") || normalized === "jp") {
      return "ja";
    }
    if (normalized.startsWith("en")) {
      return "en";
    }
    return "";
  }

  function localizedText(ja, en) {
    return isEnglishLocale ? en : ja;
  }

  function rememberLocale(locale) {
    try {
      window.localStorage.setItem("hanko-field-lang", locale);
    } catch (_) {}
  }

  function readRememberedLocale() {
    try {
      return parseLocale(window.localStorage.getItem("hanko-field-lang") || "");
    } catch (_) {
      return "";
    }
  }

  function buildLocalizedUrl(nextLocale) {
    const nextUrl = new URL(window.location.href);
    if (nextLocale === "ja") {
      nextUrl.searchParams.set("lang", "ja");
    } else {
      nextUrl.searchParams.set("lang", "en");
    }
    return `${nextUrl.pathname}${nextUrl.search}${nextUrl.hash}`;
  }

  const currentUrl = new URL(window.location.href);
  const queryLocale = parseLocale(currentUrl.searchParams.get("lang") || "");
  const rememberedLocale = readRememberedLocale();
  const pageLocale = parseLocale(document.documentElement.lang || "");
  const initialLocale =
    queryLocale ||
    parseLocale(localeInput?.value || "") ||
    pageLocale ||
    rememberedLocale ||
    "en";

  if (localeInput) {
    localeInput.value = initialLocale;
  }
  localeSelects.forEach((select) => {
    select.value = initialLocale;
    select.addEventListener("change", () => {
      const nextLocale = parseLocale(select.value) || "en";
      rememberLocale(nextLocale);
      if (localeInput) {
        localeInput.value = nextLocale;
      }
      saveDraft();
      window.location.assign(buildLocalizedUrl(nextLocale));
    });
  });
  rememberLocale(initialLocale);

  const languageSwitchers = Array.from(
    document.querySelectorAll("[data-language-switcher]"),
  );
  const languageOptions = Array.from(
    document.querySelectorAll("[data-language-option]"),
  );

  languageOptions.forEach((option) => {
    option.addEventListener("click", (event) => {
      event.preventDefault();
      const nextLocale = parseLocale(option.dataset.languageOption || "") || "en";
      rememberLocale(nextLocale);
      window.location.assign(buildLocalizedUrl(nextLocale));
    });
  });

  if (languageSwitchers.length > 0) {
    document.addEventListener("click", (event) => {
      const target = event.target;
      if (!(target instanceof Node)) {
        return;
      }

      if (languageSwitchers.some((switcher) => switcher.contains(target))) {
        return;
      }

      languageSwitchers.forEach((switcher) => {
        switcher.removeAttribute("open");
      });
    });

    document.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") {
        return;
      }

      languageSwitchers.forEach((switcher) => {
        switcher.removeAttribute("open");
      });
    });
  }

  const form = document.getElementById("order-form");
  if (!form) {
    return;
  }

  const panels = Array.from(document.querySelectorAll("[data-step-panel]"));
  const indicators = Array.from(document.querySelectorAll("[data-step-indicator]"));

  const line1Input = document.getElementById("seal_line1");
  const line2Input = document.getElementById("seal_line2");
  const sealTextError = document.getElementById("seal_text_error");
  const kanjiStyleSelect = document.getElementById("kanji_style");
  const fontInput = document.getElementById("font");
  const toggleWritingModeButton = document.getElementById("toggle-writing-mode");
  const countrySelect = document.getElementById("country");
  const fontChips = Array.from(document.querySelectorAll(".font-chip"));
  const sealLineInputs = [line1Input, line2Input].filter(Boolean);
  const shapeOptionChips = Array.from(
    document.querySelectorAll(".shape-fieldset .option-chip"),
  );
  const preview = document.getElementById("seal-preview");
  const previewLine1 = document.getElementById("seal-preview-line1");
  const previewLine2 = document.getElementById("seal-preview-line2");
  const previewCaption = document.getElementById("preview-caption");
  const materialRadios = Array.from(form.querySelectorAll("input[name='material']"));
  const materialFilterGroups = Array.from(
    document.querySelectorAll("[data-material-filter-group]"),
  );
  const materialFilterResetButton = document.querySelector(
    "[data-material-filter-reset]",
  );
  const materialFilterSummary = document.querySelector(
    "[data-material-filter-summary]",
  );
  const materialFilterEmpty = document.querySelector(
    "[data-material-filter-empty]",
  );
  const materialFilterState = {
    color: normalizeMaterialFilterValue(currentUrl.searchParams.get("color_family") || ""),
    pattern: normalizeMaterialFilterValue(currentUrl.searchParams.get("pattern_primary") || ""),
    stoneShape: normalizeMaterialFilterValue(currentUrl.searchParams.get("stone_shape") || ""),
  };

  const summarySealLines = document.getElementById("summary-seal-lines");
  const summaryShape = document.getElementById("summary-shape");
  const summaryFont = document.getElementById("summary-font");
  const summaryMaterial = document.getElementById("summary-material");
  const summaryCountry = document.getElementById("summary-country");
  const summarySubtotal = document.getElementById("summary-subtotal");
  const summaryShipping = document.getElementById("summary-shipping");
  const summaryTotal = document.getElementById("summary-total");
  const purchaseButton = document.getElementById("purchase-submit");
  const purchaseStatus = document.getElementById("purchase-status");
  const purchaseResult = document.getElementById("purchase-result");
  const recipientNameInput = document.getElementById("recipient_name");
  const emailInput = document.getElementById("email");
  const phoneInput = document.getElementById("phone");
  const postalCodeInput = document.getElementById("postal_code");
  const stateInput = document.getElementById("state");
  const cityInput = document.getElementById("city");
  const addressLine1Input = document.getElementById("address_line1");
  const termsAgreedInput = document.getElementById("terms_agreed");

  let purchaseSubmitting = false;
  let purchaseErrorMessage = "";

  form.addEventListener("input", () => {
    saveDraft();
    if (!purchaseSubmitting) {
      clearPurchaseResult();
      purchaseErrorMessage = "";
    }
    renderPurchaseStatus();
  });
  form.addEventListener("change", () => {
    saveDraft();
    if (!purchaseSubmitting) {
      clearPurchaseResult();
      purchaseErrorMessage = "";
    }
    renderPurchaseStatus();
  });

  let currentStep = 1;

  const shapeLabelMap = isEnglishLocale
    ? {
        square: "Square seal",
        round: "Round seal",
      }
    : {
        square: "角印",
        round: "丸印",
      };

  const previewShapeMap = isEnglishLocale
    ? {
        square: "Square",
        round: "Round",
      }
    : {
        square: "角",
        round: "丸",
      };
  const PINYIN_TONE_MAP = {
    ā: "a",
    á: "a",
    ǎ: "a",
    à: "a",
    ē: "e",
    é: "e",
    ě: "e",
    è: "e",
    ī: "i",
    í: "i",
    ǐ: "i",
    ì: "i",
    ō: "o",
    ó: "o",
    ǒ: "o",
    ò: "o",
    ū: "u",
    ú: "u",
    ǔ: "u",
    ù: "u",
    ǖ: "ü",
    ǘ: "ü",
    ǚ: "ü",
    ǜ: "ü",
    ń: "n",
    ň: "n",
    ǹ: "n",
    ḿ: "m",
  };
  const DEFAULT_KANJI_STYLE = "japanese";
  const MAX_SEAL_CHAR_TOTAL = 2;
  const STEP_HASH_TO_VALUE = {
    "#step-2": 2,
    "#step-3": 3,
  };
  const STEP_VALUE_TO_HASH = {
    1: "",
    2: "#step-2",
    3: "#step-3",
  };
  const DRAFT_STORAGE_KEY = "hanko-field-order-draft-v1";

  function hasStepHash(hash = window.location.hash) {
    return Object.prototype.hasOwnProperty.call(
      STEP_HASH_TO_VALUE,
      (hash || "").toLowerCase(),
    );
  }

  function clearDraftStorage() {
    try {
      window.localStorage.removeItem(DRAFT_STORAGE_KEY);
    } catch (_) {}
  }

  function saveDraft() {
    clearDraftStorage();
  }

  function normalizeStep(step) {
    return step === 2 || step === 3 ? step : 1;
  }

  function stepFromHash(hash = window.location.hash) {
    return STEP_HASH_TO_VALUE[(hash || "").toLowerCase()] || 1;
  }

  function syncHashToStep(step) {
    const nextHash = STEP_VALUE_TO_HASH[step] || "";
    if ((window.location.hash || "") === nextHash) {
      return;
    }

    if (nextHash === "") {
      window.history.pushState(null, "", `${window.location.pathname}${window.location.search}`);
      return;
    }

    window.location.hash = nextHash;
  }

  function formatUsd(cents) {
    const normalized = Number(cents);
    const amountCents = Number.isFinite(normalized) ? Math.trunc(normalized) : 0;
    const sign = amountCents < 0 ? "-" : "";
    const absoluteCents = Math.abs(amountCents);
    const whole = Math.floor(absoluteCents / 100);
    const fraction = absoluteCents % 100;
    return `${sign}USD ${whole.toLocaleString("en-US")}.${String(fraction).padStart(2, "0")}`;
  }

  function formatJpy(yen) {
    const normalized = Number(yen);
    const amountYen = Number.isFinite(normalized) ? Math.trunc(normalized) : 0;
    const sign = amountYen < 0 ? "-" : "";
    const absoluteYen = Math.abs(amountYen);
    return `${sign}JPY ${absoluteYen.toLocaleString("ja-JP")}`;
  }

  function formatMoney(amount) {
    return isEnglishLocale ? formatUsd(amount) : formatJpy(amount);
  }

  function getRawSealLines() {
    return {
      line1: line1Input?.value.trim() || "",
      line2: line2Input?.value.trim() || "",
    };
  }

  function getPreviewSealLines() {
    const { line1, line2 } = getRawSealLines();
    const line1Chars = Array.from(line1).slice(0, MAX_SEAL_CHAR_TOTAL);
    const remainingForLine2 = Math.max(0, MAX_SEAL_CHAR_TOTAL - line1Chars.length);
    const line2Chars = Array.from(line2).slice(0, remainingForLine2);

    return {
      line1: line1Chars.join(""),
      line2: line2Chars.join(""),
    };
  }

  function showStep(step, { syncHash = true } = {}) {
    const normalizedStep = normalizeStep(step);
    currentStep = normalizedStep;

    panels.forEach((panel) => {
      const panelStep = Number(panel.dataset.stepPanel);
      panel.classList.toggle("is-active", panelStep === normalizedStep);
    });

    indicators.forEach((indicator) => {
      const indicatorStep = Number(indicator.dataset.stepIndicator);
      indicator.classList.toggle("is-active", indicatorStep === normalizedStep);
      indicator.classList.toggle("is-done", indicatorStep < normalizedStep);
      if (indicatorStep === normalizedStep) {
        indicator.setAttribute("aria-current", "step");
      } else {
        indicator.removeAttribute("aria-current");
      }
    });

    if (syncHash) {
      syncHashToStep(normalizedStep);
    }

    saveDraft();
  }

  indicators.forEach((indicator) => {
    indicator.addEventListener("click", () => {
      const target = Number(indicator.dataset.stepIndicator);
      if (!Number.isFinite(target)) {
        return;
      }

      if (target > currentStep && !validateSealText()) {
        showStep(1);
        return;
      }

      if (target >= 3 && !selectedMaterial()) {
        updateSummary();
        showStep(2);
        return;
      }

      updateSummary();
      showStep(target);
    });
  });

  function syncShapeOptionStates() {
    shapeOptionChips.forEach((chip) => {
      const radio = chip.querySelector("input[name='shape']");
      chip.classList.toggle("is-selected", Boolean(radio?.checked));
    });
  }

  function setSealTextErrorState(message) {
    if (!sealTextError) {
      return;
    }

    const hasError = message !== "";
    sealTextError.textContent = message;
    sealTextError.classList.toggle("is-visible", hasError);

    sealLineInputs.forEach((input) => {
      input.classList.toggle("is-invalid", hasError);
      input.setAttribute("aria-invalid", hasError ? "true" : "false");
    });
  }

  function validateSealText() {
    if (!line1Input || !line2Input || !sealTextError) {
      return true;
    }

    const { line1, line2 } = getRawSealLines();

    if ([...line1].length === 0) {
      setSealTextErrorState(
        localizedText("お名前を入力してください。", "Enter the seal text."),
      );
      return false;
    }

    if (/\s/u.test(line1)) {
      setSealTextErrorState(
        localizedText("1行目に空白は使えません。", "No spaces are allowed in line 1."),
      );
      return false;
    }

    if (line2 !== "" && /\s/u.test(line2)) {
      setSealTextErrorState(
        localizedText("2行目に空白は使えません。", "No spaces are allowed in line 2."),
      );
      return false;
    }

    if ([...line1].length + [...line2].length > MAX_SEAL_CHAR_TOTAL) {
      setSealTextErrorState(
        localizedText(
          "印影テキストは1行目と2行目の合計で2文字以内で入力してください。",
          "Enter at most 2 characters total across lines 1 and 2.",
        ),
      );
      return false;
    }

    setSealTextErrorState("");
    return true;
  }

  function selectedShape() {
    return form.querySelector("input[name='shape']:checked")?.value || "square";
  }

  function selectedMaterial() {
    return materialRadios.find((radio) => radio.checked && !radio.disabled) || null;
  }

  function normalizeMaterialFilterValue(rawValue) {
    return (rawValue || "").trim().toLowerCase();
  }

  function parseMaterialFilterValues(rawValue) {
    return (rawValue || "")
      .split("|")
      .map((value) => normalizeMaterialFilterValue(value))
      .filter((value) => value !== "");
  }

  function updateMaterialFilterChipStates() {
    materialFilterGroups.forEach((group) => {
      const groupName = group.dataset.materialFilterGroup || "";
      const activeValue = normalizeMaterialFilterValue(
        materialFilterState[groupName] || "",
      );

      group.querySelectorAll(".material-filter-chip").forEach((button) => {
        const buttonValue = normalizeMaterialFilterValue(
          button.dataset.filterValue || "",
        );
        const isSelected = buttonValue === activeValue;
        button.classList.toggle("is-selected", isSelected);
        button.setAttribute("aria-pressed", isSelected ? "true" : "false");
      });
    });
  }

  function syncMaterialFilterUrl() {
    const nextUrl = new URL(window.location.href);

    if (materialFilterState.color) {
      nextUrl.searchParams.set("color_family", materialFilterState.color);
    } else {
      nextUrl.searchParams.delete("color_family");
    }

    if (materialFilterState.pattern) {
      nextUrl.searchParams.set("pattern_primary", materialFilterState.pattern);
    } else {
      nextUrl.searchParams.delete("pattern_primary");
    }

    if (materialFilterState.stoneShape) {
      nextUrl.searchParams.set("stone_shape", materialFilterState.stoneShape);
    } else {
      nextUrl.searchParams.delete("stone_shape");
    }

    window.history.replaceState(
      null,
      "",
      `${nextUrl.pathname}${nextUrl.search}${nextUrl.hash}`,
    );
  }

  function syncMaterialFilters() {
    const shape = selectedShape();
    const visibleRadios = [];
    let selectedVisibleRadio = null;
    let visibleCount = 0;

    materialRadios.forEach((radio) => {
      const card = radio.closest(".material-card");
      const supportedSealShapes = parseMaterialFilterValues(
        radio.dataset.supportedSealShapes || "",
      );
      const matchesShape =
        supportedSealShapes.length === 0
          ? (radio.dataset.shape || "square") === shape
          : supportedSealShapes.includes(shape);
      const colorFamily = normalizeMaterialFilterValue(
        radio.dataset.colorFamily || "",
      );
      const patternPrimary = normalizeMaterialFilterValue(
        radio.dataset.patternPrimary || "",
      );
      const stoneShape = normalizeMaterialFilterValue(radio.dataset.stoneShape || "");
      const colorFilter = normalizeMaterialFilterValue(materialFilterState.color);
      const patternFilter = normalizeMaterialFilterValue(materialFilterState.pattern);
      const stoneShapeFilter = normalizeMaterialFilterValue(
        materialFilterState.stoneShape,
      );
      const matchesColor = colorFilter === "" || colorFamily === colorFilter;
      const matchesPattern = patternFilter === "" || patternPrimary === patternFilter;
      const matchesStoneShape =
        stoneShapeFilter === "" || stoneShape === stoneShapeFilter;
      const matches =
        matchesShape && matchesColor && matchesPattern && matchesStoneShape;

      radio.disabled = !matches;
      if (card) {
        card.hidden = !matches;
      }
      if (!matches && radio.checked) {
        radio.checked = false;
      }
      if (matches) {
        visibleCount += 1;
        visibleRadios.push(radio);
        if (radio.checked) {
          selectedVisibleRadio = radio;
        }
      }
    });

    if (!selectedVisibleRadio && visibleRadios.length > 0) {
      visibleRadios[0].checked = true;
      selectedVisibleRadio = visibleRadios[0];
    }

    updateMaterialFilterChipStates();
    syncShapeOptionStates();
    syncMaterialFilterUrl();

    if (materialFilterSummary) {
      materialFilterSummary.textContent = localizedText(
        `${visibleCount}件の材質が表示されています。`,
        `${visibleCount} materials are shown.`,
      );
    }
    if (materialFilterEmpty) {
      materialFilterEmpty.hidden = visibleCount > 0;
    }

    renderPurchaseStatus();
    return selectedVisibleRadio;
  }

  function selectedCountry() {
    if (!countrySelect) {
      return null;
    }

    return countrySelect.selectedOptions[0] || null;
  }

  function selectedKanjiStyle() {
    const style = (kanjiStyleSelect?.value || "").trim().toLowerCase();
    if (style === "chinese" || style === "taiwanese") {
      return style;
    }
    return DEFAULT_KANJI_STYLE;
  }

  function isChineseStyle(style) {
    return style === "chinese" || style === "taiwanese";
  }

  function normalizePinyinWithoutTone(rawReading) {
    const normalized = Array.from((rawReading || "").trim().toLowerCase())
      .map((char) => PINYIN_TONE_MAP[char] || char)
      .join("")
      .replace(/u:/g, "ü")
      .replace(/[1-5]/g, "")
      .replace(/\s+/g, " ")
      .trim();
    return normalized;
  }

  function styleMatchedFontChips() {
    const selectedStyle = selectedKanjiStyle();
    return fontChips.filter((chip) => {
      const chipStyle = (chip.dataset.fontStyle || DEFAULT_KANJI_STYLE).trim().toLowerCase();
      return chipStyle === selectedStyle && !chip.hidden && !chip.disabled;
    });
  }

  function getSelectedFontChip() {
    if (fontChips.length === 0) {
      return null;
    }

    const matchedChips = styleMatchedFontChips();
    const selectedByInput = matchedChips.find((chip) => chip.dataset.fontKey === fontInput?.value);
    if (selectedByInput) {
      return selectedByInput;
    }

    return matchedChips[0] || null;
  }

  function setSelectedFontChip(chip) {
    fontChips.forEach((currentChip) => {
      const isSelected = currentChip === chip;
      currentChip.classList.toggle("is-selected", isSelected);
      currentChip.setAttribute("aria-pressed", isSelected ? "true" : "false");
    });

    if (fontInput) {
      fontInput.value = chip?.dataset.fontKey || "";
    }
  }

  function syncFontOptionsByStyle() {
    const selectedStyle = selectedKanjiStyle();
    const visibleChips = [];

    fontChips.forEach((chip) => {
      const chipStyle = (chip.dataset.fontStyle || DEFAULT_KANJI_STYLE).trim().toLowerCase();
      const matchesStyle = chipStyle === selectedStyle;
      chip.hidden = !matchesStyle;
      chip.disabled = !matchesStyle;
      chip.setAttribute("aria-disabled", matchesStyle ? "false" : "true");
      if (matchesStyle) {
        visibleChips.push(chip);
      }
    });

    const selectedByInput = visibleChips.find((chip) => chip.dataset.fontKey === fontInput?.value);
    setSelectedFontChip(selectedByInput || visibleChips[0] || null);
  }

  function updateFontChipPreviews() {
    const { line1, line2 } = getPreviewSealLines();
    const previewText = line1 ? (line2 ? `${line1}\n${line2}` : line1) : "印";

    fontChips.forEach((chip) => {
      const chipPreview = chip.querySelector("[data-font-preview]");
      if (chipPreview) {
        chipPreview.style.fontFamily = chip.dataset.fontFamily || "'Zen Maru Gothic', sans-serif";
        chipPreview.textContent = previewText;
      }
    });
  }

  function swapCrossLineCharacters() {
    if (!line1Input || !line2Input) {
      return;
    }

    const line1Chars = Array.from(line1Input.value.trim());
    const line2Chars = Array.from(line2Input.value.trim());

    if (line1Chars.length >= 2 && line2Chars.length === 0) {
      line1Input.value = line1Chars.slice(0, 1).join("");
      line2Input.value = line1Chars.slice(1, 2).join("");
      return;
    }

    if (line1Chars.length >= 1 && line2Chars.length >= 1) {
      line1Input.value = `${line1Chars[0]}${line2Chars[0]}`;
      line2Input.value = "";
      return;
    }
  }

  function updatePreview() {
    if (!preview || !previewLine1 || !previewLine2 || !previewCaption) {
      return;
    }

    const { line1, line2 } = getPreviewSealLines();

    const previewLine1Text = line1 || "印";
    const hasSecondLine = line2 !== "";

    previewLine1.textContent = previewLine1Text;
    previewLine2.textContent = line2;
    previewLine2.hidden = !hasSecondLine;

    const selectedFontChip = getSelectedFontChip();
    const fontFamily = selectedFontChip?.dataset.fontFamily || "'Zen Maru Gothic', sans-serif";
    previewLine1.style.fontFamily = fontFamily;
    previewLine2.style.fontFamily = fontFamily;

    const shape = selectedShape();
    preview.classList.toggle("is-round", shape === "round");
    preview.classList.toggle("is-square", shape !== "round");
    preview.classList.toggle("mode-two-lines", hasSecondLine);
    preview.classList.toggle("mode-single-char", !hasSecondLine && [...previewLine1Text].length === 1);
    preview.classList.toggle("mode-single-line", !hasSecondLine && [...previewLine1Text].length > 1);

    previewCaption.textContent = `${previewShapeMap[shape] || "角"} / ${selectedFontChip?.dataset.fontLabel || "-"}`;
  }

  function updateSummary() {
    if (
      !summarySealLines ||
      !summaryShape ||
      !summaryFont ||
      !summaryMaterial ||
      !summaryCountry ||
      !summarySubtotal ||
      !summaryShipping ||
      !summaryTotal
    ) {
      return;
    }

    const { line1, line2 } = getPreviewSealLines();
    if (line1 === "") {
      summarySealLines.textContent = "-";
    } else {
      summarySealLines.textContent = line2 ? `${line1}\n${line2}` : line1;
    }

    const shape = selectedShape();
    summaryShape.textContent = shapeLabelMap[shape] || "-";

    const selectedFontChip = getSelectedFontChip();
    summaryFont.textContent = selectedFontChip?.dataset.fontLabel || "-";

    const material = selectedMaterial();
    summaryMaterial.textContent = material?.dataset.label || "-";

    const country = selectedCountry();
    const shipping = Number(country?.dataset.shipping || 0);
    summaryCountry.textContent = country?.dataset.label || "-";

    const subtotal = Number(material?.dataset.price || 0);
    summarySubtotal.textContent = material ? formatMoney(subtotal) : "-";
    summaryShipping.textContent = country ? formatMoney(shipping) : "-";
    summaryTotal.textContent = material && country ? formatMoney(subtotal + shipping) : "-";

    saveDraft();
  }

  function clearPurchaseResult() {
    if (!purchaseResult) {
      return;
    }

    purchaseResult.replaceChildren();
  }

  function setPurchaseErrorMessage(message) {
    purchaseErrorMessage = message;
  }

  function purchaseValidationGroups() {
    const groups = [];

    const sealIssues = [];
    const sealError = (sealTextError?.textContent || "").trim();
    const sealLine1Value = line1Input?.value.trim() || "";
    if (sealError !== "") {
      sealIssues.push(sealError);
    } else if (sealLine1Value === "") {
      sealIssues.push(
        localizedText(
          "お名前（印影テキスト）を入力してください。",
          "Enter the seal text.",
        ),
      );
    }
    if (sealIssues.length > 0) {
      groups.push({
        label: localizedText("印影テキスト", "Seal text"),
        items: sealIssues,
      });
    }

    if (!selectedMaterial()) {
      groups.push({
        label: localizedText("材質", "Material"),
        items: [
          localizedText(
            "材質を選択してください。",
            "Choose a material before continuing.",
          ),
        ],
      });
    }

    const shippingIssues = [];
    if ((recipientNameInput?.value.trim() || "") === "") {
      shippingIssues.push(
        localizedText("お届け先氏名", "Recipient name"),
      );
    }

    const emailValue = emailInput?.value.trim() || "";
    if (emailValue === "") {
      shippingIssues.push(localizedText("メールアドレス", "Email address"));
    } else if (emailInput && !emailInput.checkValidity()) {
      shippingIssues.push(
        localizedText(
          "メールアドレスの形式が正しくありません。",
          "Enter a valid email address.",
        ),
      );
    }

    if ((phoneInput?.value.trim() || "") === "") {
      shippingIssues.push(localizedText("電話番号", "Phone number"));
    }
    if ((postalCodeInput?.value.trim() || "") === "") {
      shippingIssues.push(localizedText("郵便番号", "Postal code"));
    }
    if ((stateInput?.value.trim() || "") === "") {
      shippingIssues.push(
        localizedText("都道府県 / 州", "State / Prefecture"),
      );
    }
    if ((cityInput?.value.trim() || "") === "") {
      shippingIssues.push(localizedText("市区町村 / City", "City"));
    }
    if ((addressLine1Input?.value.trim() || "") === "") {
      shippingIssues.push(localizedText("住所1", "Address line 1"));
    }
    if (shippingIssues.length > 0) {
      groups.push({
        label: localizedText("お届け先情報", "Shipping details"),
        items: shippingIssues,
      });
    }

    if (!termsAgreedInput?.checked) {
      groups.push({
        label: localizedText("同意", "Agreement"),
        items: [
          localizedText(
            "利用規約への同意",
            "Agree to the terms of service",
          ),
        ],
      });
    }

    return groups;
  }

  function renderPurchaseStatus() {
    if (!purchaseStatus || !purchaseButton) {
      return;
    }

    const groups = purchaseValidationGroups();
    const isSubmitting = purchaseSubmitting;
    const isBlocked = !isSubmitting && groups.length > 0;
    const hasError = !isSubmitting && !isBlocked && purchaseErrorMessage !== "";
    const state = isSubmitting
      ? "submitting"
      : isBlocked
      ? "blocked"
      : hasError
      ? "error"
      : "ready";
    const readyLabel =
      purchaseButton.dataset.readyLabel || purchaseButton.textContent || "";
    const submittingLabel =
      purchaseButton.dataset.submittingLabel ||
      localizedText("送信中...", "Submitting...");
    const hasPurchaseResult = Boolean(purchaseResult?.childElementCount);

    if (!isSubmitting && !isBlocked && !hasError && hasPurchaseResult) {
      purchaseButton.disabled = false;
      purchaseButton.setAttribute("aria-busy", "false");
      purchaseButton.setAttribute("aria-disabled", "false");
      purchaseButton.classList.remove("is-loading");
      purchaseButton.textContent = readyLabel;
      purchaseStatus.replaceChildren();
      purchaseStatus.hidden = true;
      return;
    }

    purchaseButton.disabled = isSubmitting || isBlocked;
    purchaseButton.setAttribute("aria-busy", isSubmitting ? "true" : "false");
    purchaseButton.setAttribute(
      "aria-disabled",
      purchaseButton.disabled ? "true" : "false",
    );
    purchaseButton.classList.toggle("is-loading", isSubmitting);
    purchaseButton.textContent = isSubmitting ? submittingLabel : readyLabel;

    purchaseStatus.hidden = false;
    purchaseStatus.className = `purchase-status is-${state}`;
    purchaseStatus.replaceChildren();

    const header = document.createElement("div");
    header.className = "purchase-status__header";

    const title = document.createElement("p");
    title.className = "purchase-status__title";
    title.textContent = isSubmitting
      ? localizedText("送信中", "Submitting")
      : isBlocked
      ? localizedText("入力が不足しています", "Missing details")
      : hasError
      ? localizedText("送信に失敗しました", "Submission failed")
      : localizedText("送信準備完了", "Ready to submit");

    header.append(title);
    purchaseStatus.append(header);

    const message = document.createElement("p");
    message.className = "purchase-status__message";
    message.textContent = isSubmitting
      ? localizedText(
          "Stripe Checkout への送信を準備しています。",
          "Submitting the order and preparing Stripe Checkout.",
        )
      : isBlocked
      ? localizedText(
          "未入力または未確認の項目を確認してください。",
          "Review the missing or unconfirmed details below.",
        )
      : hasError
      ? purchaseErrorMessage
      : localizedText(
          "入力が揃いました。支払いへ進めます。",
          "All required details are ready. You can proceed to payment.",
        );
    purchaseStatus.append(message);

    if (isBlocked) {
      const groupsWrap = document.createElement("div");
      groupsWrap.className = "purchase-status__groups";

      groups.forEach((group) => {
        const groupWrap = document.createElement("div");

        const groupTitle = document.createElement("p");
        groupTitle.className = "purchase-status__group-title";
        groupTitle.textContent = group.label;
        groupWrap.append(groupTitle);

        const chips = document.createElement("div");
        chips.className = "purchase-status__chips";
        group.items.forEach((item) => {
          const chip = document.createElement("span");
          chip.className = "purchase-status__chip";
          chip.textContent = item;
          chips.append(chip);
        });
        groupWrap.append(chips);

        groupsWrap.append(groupWrap);
      });

      purchaseStatus.append(groupsWrap);
    }
  }

  function syncMaterialOptionsByShape() {
    syncMaterialFilters();
  }

  form.querySelectorAll("[data-next-step]").forEach((button) => {
    button.addEventListener("click", () => {
      const next = Number(button.dataset.nextStep);
      if (next >= 2 && !validateSealText()) {
        showStep(1);
        return;
      }

      if (next >= 3 && !selectedMaterial()) {
        updateSummary();
        showStep(2);
        return;
      }

      updateSummary();
      showStep(next);
    });
  });

  form.querySelectorAll("[data-prev-step]").forEach((button) => {
    button.addEventListener("click", () => {
      const prev = Number(button.dataset.prevStep);
      showStep(prev);
    });
  });

  function refreshSealUi() {
    validateSealText();
    updateFontChipPreviews();
    updatePreview();
    updateSummary();
    renderPurchaseStatus();
  }

  [line1Input, line2Input].forEach((input) => {
    input?.addEventListener("input", refreshSealUi);
    input?.addEventListener("change", refreshSealUi);
  });

  fontChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      setSelectedFontChip(chip);
      updatePreview();
      updateSummary();
    });
  });

  kanjiStyleSelect?.addEventListener("change", () => {
    syncFontOptionsByStyle();
    refreshSealUi();
  });

  form.querySelectorAll("input[name='shape']").forEach((radio) => {
    radio.addEventListener("change", () => {
      syncMaterialOptionsByShape();
      updatePreview();
      updateSummary();
    });
  });

  materialFilterGroups.forEach((group) => {
    group.addEventListener("click", (event) => {
      const button = event.target.closest(".material-filter-chip");
      if (!button) {
        return;
      }

      const groupName = group.dataset.materialFilterGroup || "";
      if (!groupName || !(groupName in materialFilterState)) {
        return;
      }

      const selectedValue = normalizeMaterialFilterValue(
        button.dataset.filterValue || "",
      );
      const currentValue = normalizeMaterialFilterValue(
        materialFilterState[groupName],
      );
      materialFilterState[groupName] = currentValue === selectedValue ? "" : selectedValue;
      syncMaterialFilters();
      updatePreview();
      updateSummary();
    });
  });

  materialFilterResetButton?.addEventListener("click", () => {
    materialFilterState.color = "";
    materialFilterState.pattern = "";
    materialFilterState.stoneShape = "";
    syncMaterialFilters();
    updatePreview();
    updateSummary();
  });

  materialRadios.forEach((radio) => {
    radio.addEventListener("change", updateSummary);
  });

  countrySelect?.addEventListener("change", updateSummary);
  toggleWritingModeButton?.addEventListener("click", () => {
    swapCrossLineCharacters();
    refreshSealUi();
  });

  purchaseButton?.addEventListener("click", (event) => {
    if (purchaseSubmitting) {
      event.preventDefault();
      return;
    }

    if (purchaseValidationGroups().length > 0) {
      event.preventDefault();
      renderPurchaseStatus();
    }
  });

  purchaseButton?.addEventListener("htmx:beforeRequest", () => {
    purchaseSubmitting = true;
    purchaseErrorMessage = "";
    clearPurchaseResult();
    renderPurchaseStatus();
  });

  const endPurchaseSubmission = () => {
    purchaseSubmitting = false;
    renderPurchaseStatus();
  };

  purchaseButton?.addEventListener("htmx:afterRequest", (event) => {
    const redirectUrl = event.detail?.xhr
      ?.getResponseHeader("HX-Redirect")
      ?.trim();

    // HX-Redirect responses do not swap content, so finish the loading state
    // when the request succeeds and let the browser handle the navigation.
    if (redirectUrl) {
      endPurchaseSubmission();
      window.location.assign(redirectUrl);
      return;
    }

    if (event.detail?.successful) {
      endPurchaseSubmission();
    }
  });
  purchaseButton?.addEventListener("htmx:responseError", () => {
    setPurchaseErrorMessage(
      localizedText(
        "決済リクエストに失敗しました。通信環境を確認して、もう一度お試しください。",
        "The payment request failed. Check your connection and try again.",
      ),
    );
    endPurchaseSubmission();
  });
  purchaseButton?.addEventListener("htmx:timeout", () => {
    setPurchaseErrorMessage(
      localizedText(
        "決済リクエストがタイムアウトしました。通信環境を確認して、もう一度お試しください。",
        "The payment request timed out. Check your connection and try again.",
      ),
    );
    endPurchaseSubmission();
  });
  purchaseButton?.addEventListener("htmx:sendError", () => {
    setPurchaseErrorMessage(
      localizedText(
        "決済リクエストを送信できませんでした。通信環境を確認して、もう一度お試しください。",
        "The payment request could not be sent. Check your connection and try again.",
      ),
    );
    endPurchaseSubmission();
  });

  document.body.addEventListener("click", (event) => {
    const chip = event.target.closest(".kanji-chip");
    if (!chip || !line1Input || !line2Input) {
      return;
    }

    const line1 = (chip.dataset.line1 || "").trim();
    const line2 = (chip.dataset.line2 || "").trim();

    if (line1 !== "" || line2 !== "") {
      line1Input.value = line1.slice(0, 2);
      line2Input.value = line2.slice(0, 2);
    } else {
      const candidate = (chip.textContent || "").trim();
      const chars = Array.from(candidate).slice(0, MAX_SEAL_CHAR_TOTAL);
      line1Input.value = chars.join("");
      line2Input.value = "";
    }

    refreshSealUi();

    const suggestionsContainer = chip.closest("#kanji-suggestions");
    if (suggestionsContainer) {
      suggestionsContainer.querySelectorAll(".kanji-chip").forEach((button) => {
        button.classList.toggle("is-selected", button === chip);
      });

      const reasonBox = suggestionsContainer.querySelector("[data-kanji-reason]");
      if (reasonBox) {
        reasonBox.textContent =
          chip.dataset.reason ||
          localizedText(
            "この候補の理由を表示できませんでした。",
            "Could not show the reason for this suggestion.",
          );
      }

      const readingBox = suggestionsContainer.querySelector("[data-kanji-reading]");
      if (readingBox) {
        const reading = (chip.dataset.reading || chip.dataset.romaji || "").trim();
        const style = (chip.dataset.kanjiStyle || selectedKanjiStyle()).trim().toLowerCase();

        if (isChineseStyle(style)) {
          const pinyin = normalizePinyinWithoutTone(reading);
          if (pinyin) {
            readingBox.textContent = localizedText(
              `読み方(拼音): ${pinyin}`,
              `Reading (Pinyin): ${pinyin}`,
            );
          } else {
            readingBox.textContent = localizedText(
              "この候補の読み方を表示できませんでした。",
              "Could not show the reading for this suggestion.",
            );
          }
        } else if (reading) {
          const normalizedReading = reading.toLowerCase();
          readingBox.textContent = localizedText(
            `読み方(ローマ字): ${normalizedReading}`,
            `Reading (Romaji): ${normalizedReading}`,
          );
        } else {
          readingBox.textContent = localizedText(
            "この候補の読み方を表示できませんでした。",
            "Could not show the reading for this suggestion.",
          );
        }
      }
    }
  });

  // Keep the checkout stateless so a cache clear or hard reload returns to step 1.
  clearDraftStorage();
  form.reset();
  if (localeInput) {
    localeInput.value = initialLocale;
  }
  clearPurchaseResult();
  syncMaterialOptionsByShape();
  syncFontOptionsByStyle();
  showStep(1, { syncHash: false });
  window.history.replaceState(
    null,
    "",
    `${window.location.pathname}${window.location.search}`,
  );
  refreshSealUi();
  renderPurchaseStatus();
  window.addEventListener("hashchange", () => {
    showStep(stepFromHash(), { syncHash: false });
  });
})();
