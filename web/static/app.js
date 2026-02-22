(() => {
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
  const preview = document.getElementById("seal-preview");
  const previewLine1 = document.getElementById("seal-preview-line1");
  const previewLine2 = document.getElementById("seal-preview-line2");
  const previewCaption = document.getElementById("preview-caption");
  const materialRadios = Array.from(form.querySelectorAll("input[name='material']"));

  const summarySealLines = document.getElementById("summary-seal-lines");
  const summaryShape = document.getElementById("summary-shape");
  const summaryFont = document.getElementById("summary-font");
  const summaryMaterial = document.getElementById("summary-material");
  const summaryCountry = document.getElementById("summary-country");
  const summarySubtotal = document.getElementById("summary-subtotal");
  const summaryShipping = document.getElementById("summary-shipping");
  const summaryTotal = document.getElementById("summary-total");

  let currentStep = 1;

  const shapeLabelMap = {
    square: "角印",
    round: "丸印",
  };

  const previewShapeMap = {
    square: "角",
    round: "丸",
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

  function formatYen(amount) {
    return `¥${Number(amount).toLocaleString("ja-JP")}`;
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
    });

    if (syncHash) {
      syncHashToStep(normalizedStep);
    }
  }

  function validateSealText() {
    if (!line1Input || !line2Input || !sealTextError) {
      return true;
    }

    const { line1, line2 } = getRawSealLines();

    if ([...line1].length === 0) {
      sealTextError.textContent = "お名前を入力してください。";
      return false;
    }

    if (/\s/u.test(line1)) {
      sealTextError.textContent = "1行目に空白は使えません。";
      return false;
    }

    if (line2 !== "" && /\s/u.test(line2)) {
      sealTextError.textContent = "2行目に空白は使えません。";
      return false;
    }

    if ([...line1].length + [...line2].length > MAX_SEAL_CHAR_TOTAL) {
      sealTextError.textContent = "印影テキストは1行目と2行目の合計で2文字以内で入力してください。";
      return false;
    }

    sealTextError.textContent = "";
    return true;
  }

  function selectedShape() {
    return form.querySelector("input[name='shape']:checked")?.value || "square";
  }

  function selectedMaterial() {
    return materialRadios.find((radio) => radio.checked && !radio.disabled) || null;
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
    summarySubtotal.textContent = material ? formatYen(subtotal) : "-";
    summaryShipping.textContent = country ? formatYen(shipping) : "-";
    summaryTotal.textContent = material && country ? formatYen(subtotal + shipping) : "-";
  }

  function syncMaterialOptionsByShape() {
    const shape = selectedShape();
    const visibleRadios = [];
    let selectedVisibleRadio = null;

    materialRadios.forEach((radio) => {
      const card = radio.closest(".material-card");
      const matchesShape = (radio.dataset.shape || "square") === shape;
      radio.disabled = !matchesShape;
      if (card) {
        card.hidden = !matchesShape;
      }
      if (!matchesShape && radio.checked) {
        radio.checked = false;
      }
      if (matchesShape) {
        visibleRadios.push(radio);
        if (radio.checked) {
          selectedVisibleRadio = radio;
        }
      }
    });

    if (!selectedVisibleRadio && visibleRadios.length > 0) {
      visibleRadios[0].checked = true;
    }
  }

  form.querySelectorAll("[data-next-step]").forEach((button) => {
    button.addEventListener("click", () => {
      const next = Number(button.dataset.nextStep);
      if (next >= 2 && !validateSealText()) {
        showStep(1);
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

  materialRadios.forEach((radio) => {
    radio.addEventListener("change", updateSummary);
  });

  countrySelect?.addEventListener("change", updateSummary);
  toggleWritingModeButton?.addEventListener("click", () => {
    swapCrossLineCharacters();
    refreshSealUi();
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
        reasonBox.textContent = chip.dataset.reason || "この候補の理由を表示できませんでした。";
      }

      const readingBox = suggestionsContainer.querySelector("[data-kanji-reading]");
      if (readingBox) {
        const hiragana = (chip.dataset.hiragana || "").trim();
        const romaji = (chip.dataset.romaji || "").trim();
        if (hiragana && romaji) {
          readingBox.textContent = `読み方: ${hiragana} / ${romaji}`;
        } else if (hiragana) {
          readingBox.textContent = `読み方: ${hiragana}`;
        } else {
          readingBox.textContent = "この候補の読み方を表示できませんでした。";
        }
      }
    }
  });

  syncMaterialOptionsByShape();
  syncFontOptionsByStyle();
  refreshSealUi();
  window.addEventListener("hashchange", () => {
    showStep(stepFromHash(), { syncHash: false });
  });
  showStep(stepFromHash(), { syncHash: false });
})();
