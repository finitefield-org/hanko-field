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
  const fontInput = document.getElementById("font");
  const fontChips = Array.from(document.querySelectorAll(".font-chip"));
  const preview = document.getElementById("seal-preview");
  const previewLine1 = document.getElementById("seal-preview-line1");
  const previewLine2 = document.getElementById("seal-preview-line2");

  const summarySealLines = document.getElementById("summary-seal-lines");
  const summaryShape = document.getElementById("summary-shape");
  const summaryFont = document.getElementById("summary-font");
  const summaryMaterial = document.getElementById("summary-material");
  const summaryPrice = document.getElementById("summary-price");

  let currentStep = 1;

  const lineRegex = /^[一-龯々〆〤ぁ-ゖァ-ヶA-Za-z0-9]{1,2}$/;

  const shapeLabelMap = {
    square: "角印",
    round: "丸印",
  };

  function formatYen(amount) {
    return `¥${Number(amount).toLocaleString("ja-JP")}`;
  }

  function getSealLines() {
    return {
      line1: line1Input?.value.trim() || "",
      line2: line2Input?.value.trim() || "",
    };
  }

  function showStep(step) {
    currentStep = step;

    panels.forEach((panel) => {
      const panelStep = Number(panel.dataset.stepPanel);
      panel.classList.toggle("is-active", panelStep === step);
    });

    indicators.forEach((indicator) => {
      const indicatorStep = Number(indicator.dataset.stepIndicator);
      indicator.classList.toggle("is-active", indicatorStep === step);
      indicator.classList.toggle("is-done", indicatorStep < step);
    });
  }

  function validateSealText() {
    if (!line1Input || !line2Input || !sealTextError) {
      return true;
    }

    const { line1, line2 } = getSealLines();

    if ([...line1].length === 0) {
      sealTextError.textContent = "印影テキスト1行目を入力してください。";
      return false;
    }

    if ([...line1].length > 2) {
      sealTextError.textContent = "印影テキスト1行目は2文字以内で入力してください。";
      return false;
    }

    if ([...line2].length > 2) {
      sealTextError.textContent = "印影テキスト2行目は2文字以内で入力してください。";
      return false;
    }

    if (!lineRegex.test(line1)) {
      sealTextError.textContent = "1行目で使える文字は漢字・ひらがな・カタカナ・英字・数字のみです。";
      return false;
    }

    if (line2 !== "" && !lineRegex.test(line2)) {
      sealTextError.textContent = "2行目で使える文字は漢字・ひらがな・カタカナ・英字・数字のみです。";
      return false;
    }

    sealTextError.textContent = "";
    return true;
  }

  function selectedShape() {
    return form.querySelector("input[name='shape']:checked")?.value || "square";
  }

  function selectedMaterial() {
    return form.querySelector("input[name='material']:checked");
  }

  function getSelectedFontChip() {
    if (fontChips.length === 0) {
      return null;
    }

    const selectedByInput = fontChips.find((chip) => chip.dataset.fontKey === fontInput?.value);
    if (selectedByInput) {
      return selectedByInput;
    }

    return fontChips[0];
  }

  function setSelectedFontChip(chip) {
    if (!chip) {
      return;
    }

    fontChips.forEach((currentChip) => {
      const isSelected = currentChip === chip;
      currentChip.classList.toggle("is-selected", isSelected);
      currentChip.setAttribute("aria-pressed", isSelected ? "true" : "false");
    });

    if (fontInput) {
      fontInput.value = chip.dataset.fontKey || "";
    }
  }

  function updateFontChipPreviews() {
    const { line1, line2 } = getSealLines();
    const previewText = line1 ? (line2 ? `${line1}\n${line2}` : line1) : "印";

    fontChips.forEach((chip) => {
      const chipPreview = chip.querySelector("[data-font-preview]");
      if (chipPreview) {
        chipPreview.style.fontFamily = chip.dataset.fontFamily || "'Zen Maru Gothic', sans-serif";
        chipPreview.textContent = previewText;
      }
    });
  }

  function updatePreview() {
    if (!preview || !previewLine1 || !previewLine2) {
      return;
    }

    const { line1, line2 } = getSealLines();

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
  }

  function updateSummary() {
    if (!summarySealLines || !summaryShape || !summaryFont || !summaryMaterial || !summaryPrice) {
      return;
    }

    const { line1, line2 } = getSealLines();
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
    summaryPrice.textContent = material ? formatYen(material.dataset.price || 0) : "-";
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

  [line1Input, line2Input].forEach((input) => {
    input?.addEventListener("input", () => {
      validateSealText();
      updateFontChipPreviews();
      updatePreview();
      updateSummary();
    });
  });

  fontChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      setSelectedFontChip(chip);
      updatePreview();
      updateSummary();
    });
  });

  form.querySelectorAll("input[name='shape']").forEach((radio) => {
    radio.addEventListener("change", () => {
      updatePreview();
      updateSummary();
    });
  });

  form.querySelectorAll("input[name='material']").forEach((radio) => {
    radio.addEventListener("change", updateSummary);
  });

  document.body.addEventListener("click", (event) => {
    const chip = event.target.closest(".kanji-chip");
    if (!chip || !line1Input || !line2Input) {
      return;
    }

    const candidate = (chip.dataset.kanji || chip.textContent || "").trim();
    const chars = Array.from(candidate).slice(0, 4);

    line1Input.value = chars.slice(0, 2).join("");
    line2Input.value = chars.slice(2, 4).join("");

    validateSealText();
    updateFontChipPreviews();
    updatePreview();
    updateSummary();
  });

  setSelectedFontChip(getSelectedFontChip());
  updateFontChipPreviews();
  updatePreview();
  updateSummary();
  showStep(currentStep);
})();
