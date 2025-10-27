package ui

import (
	"fmt"
	"net/url"
	"strings"
	"unicode"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	catalogtpl "finitefield.org/hanko-admin/internal/admin/templates/catalog"
)

type catalogModalMode string

const (
	catalogModalModeNew  catalogModalMode = "new"
	catalogModalModeEdit catalogModalMode = "edit"
)

type modalFieldSpec struct {
	Name         string
	Label        string
	Type         string
	Section      string
	Placeholder  string
	Hint         string
	Required     bool
	FullWidth    bool
	Rows         int
	InputMode    string
	Prefix       string
	Suffix       string
	Autocomplete string
	Options      []modalOptionSpec
	Asset        *assetFieldSpec
}

type modalOptionSpec struct {
	Value string
	Label string
}

type assetFieldSpec struct {
	Purpose        string
	Kind           string
	Accept         string
	MaxSize        int64
	AssetIDField   string
	URLField       string
	FileNameField  string
	DisplayPreview bool
	UploadLabel    string
	ReplaceLabel   string
	RemoveLabel    string
	EmptyLabel     string
}

func buildCatalogUpsertModal(kind admincatalog.Kind, mode catalogModalMode, values map[string]string, fieldErrors map[string]string, generalErr string, actionURL, method, csrf string) catalogtpl.ModalFormData {
	if values == nil {
		values = defaultCatalogValues(kind)
	}
	if fieldErrors == nil {
		fieldErrors = map[string]string{}
	}
	sections := buildModalSections(kind, values, fieldErrors)
	hidden := []catalogtpl.ModalHiddenField{{Name: "csrf_token", Value: csrf}}
	if version := strings.TrimSpace(values["version"]); version != "" {
		hidden = append(hidden, catalogtpl.ModalHiddenField{Name: "version", Value: version})
	}
	titleVerb := "作成"
	submitLabel := "作成する"
	submitTone := "primary"
	if mode == catalogModalModeEdit {
		titleVerb = "編集"
		submitLabel = "更新する"
		submitTone = "primary"
	}
	return catalogtpl.ModalFormData{
		Title:        fmt.Sprintf("%sを%s", kind.Label(), titleVerb),
		Description:  fmt.Sprintf("%sのプロパティを設定してください。", kind.Label()),
		Kind:         kind,
		KindLabel:    kind.Label(),
		Mode:         string(mode),
		ActionURL:    actionURL,
		Method:       method,
		SubmitLabel:  submitLabel,
		SubmitTone:   submitTone,
		HiddenFields: hidden,
		Sections:     sections,
		Error:        generalErr,
	}
}

func buildCatalogDeleteModal(kind admincatalog.Kind, detail admincatalog.ItemDetail, actionURL, csrf, generalErr string) catalogtpl.DeleteModalData {
	deps := make([]catalogtpl.DependencyView, 0, len(detail.Dependencies))
	for _, dep := range detail.Dependencies {
		deps = append(deps, catalogtpl.DependencyView{Label: dep.Label, Kind: dep.Kind, Status: dep.Status, Tone: dep.Tone})
	}
	metadata := make([]catalogtpl.MetadataView, 0, len(detail.Metadata))
	for _, entry := range detail.Metadata {
		metadata = append(metadata, catalogtpl.MetadataView{Key: entry.Key, Value: entry.Value, Icon: entry.Icon})
	}
	hidden := []catalogtpl.ModalHiddenField{{Name: "csrf_token", Value: csrf}}
	if version := strings.TrimSpace(detail.Item.Version); version != "" {
		hidden = append(hidden, catalogtpl.ModalHiddenField{Name: "version", Value: version})
	}
	return catalogtpl.DeleteModalData{
		Title:          fmt.Sprintf("%sを削除", kind.Label()),
		Description:    fmt.Sprintf("%s「%s」を削除します。", kind.Label(), detail.Item.Name),
		KindLabel:      kind.Label(),
		ItemName:       detail.Item.Name,
		ItemIdentifier: detail.Item.Identifier,
		ActionURL:      actionURL,
		Method:         "DELETE",
		SubmitLabel:    "削除する",
		SubmitTone:     "danger",
		HiddenFields:   hidden,
		Metadata:       metadata,
		Dependencies:   deps,
		Warning:        fmt.Sprintf("%sの削除は取り消せません。関連エンティティに影響する可能性があります。", kind.Label()),
		Error:          generalErr,
	}
}

func defaultCatalogValues(kind admincatalog.Kind) map[string]string {
	values := map[string]string{
		"name":            "",
		"identifier":      "",
		"description":     "",
		"status":          string(admincatalog.StatusDraft),
		"category":        defaultCategoryForKind(kind),
		"tags":            "",
		"previewURL":      samplePreviewForKind(kind),
		"previewAssetID":  "",
		"previewFileName": "",
		"primaryColor":    "#0F172A",
		"ownerName":       "Akari Sato",
		"ownerEmail":      "akari.sato@example.com",
		"templateID":      "TMP-NEW",
		"svgPath":         "/designs/templates/sample.svg",
		"svgAssetID":      "",
		"svgFileName":     "",
		"fontFamily":      "Hanko Sans",
		"fontWeights":     "400,700",
		"license":         "商用",
		"materialSKU":     "MAT-NEW",
		"color":           "ナチュラル",
		"inventory":       "500",
		"productSKU":      "PRD-NEW",
		"price":           "1980",
		"currency":        "JPY",
		"leadTime":        "5",
		"photoURLs":       "https://cdn.example.com/catalog/preview.png\nhttps://cdn.example.com/catalog/preview-alt.png",
		"version":         "v1",
	}
	switch kind {
	case admincatalog.KindFonts:
		values["category"] = "serif"
	case admincatalog.KindMaterials:
		values["category"] = "textured"
	case admincatalog.KindProducts:
		values["category"] = "seasonal_bundle"
	}
	return values
}

func defaultCategoryForKind(kind admincatalog.Kind) string {
	switch kind {
	case admincatalog.KindTemplates:
		return "seasonal"
	case admincatalog.KindFonts:
		return "serif"
	case admincatalog.KindMaterials:
		return "textured"
	case admincatalog.KindProducts:
		return "seasonal_bundle"
	default:
		return "seasonal"
	}
}

func samplePreviewForKind(kind admincatalog.Kind) string {
	switch kind {
	case admincatalog.KindFonts:
		return "https://cdn.example.com/catalog/font-preview.png"
	case admincatalog.KindMaterials:
		return "https://cdn.example.com/catalog/material-preview.png"
	case admincatalog.KindProducts:
		return "https://cdn.example.com/catalog/product-preview.png"
	default:
		return "https://cdn.example.com/catalog/template-preview.png"
	}
}

func catalogValuesFromDetail(kind admincatalog.Kind, detail admincatalog.ItemDetail) map[string]string {
	values := defaultCatalogValues(kind)
	resetPlaceholderValues(values)
	assign := func(key, value string) {
		values[key] = normalizeCatalogFormValue(key, value)
	}

	assign("name", detail.Item.Name)
	assign("identifier", detail.Item.Identifier)
	assign("description", detail.Description)
	assign("status", string(detail.Item.Status))
	assign("category", detail.Item.Category)
	assign("tags", strings.Join(detail.Tags, ", "))
	assign("previewURL", detail.PreviewURL)
	assign("previewAssetID", detail.PreviewAssetID)
	assign("previewFileName", detail.PreviewFileName)
	assign("primaryColor", detail.Item.PrimaryColor)
	assign("ownerName", detail.Owner.Name)
	assign("ownerEmail", detail.Owner.Email)
	assign("version", detail.Item.Version)
	assign("templateID", detail.Item.Identifier)
	assign("materialSKU", detail.Item.Identifier)
	assign("productSKU", detail.Item.Identifier)
	assign("svgPath", detail.SVGPath)
	assign("svgAssetID", detail.SVGAssetID)
	assign("svgFileName", detail.SVGFileName)

	if len(detail.Properties) > 0 {
		for key, value := range detail.Properties {
			assign(key, value)
		}
	}

	if strings.TrimSpace(values["photoURLs"]) == "" {
		assign("photoURLs", detail.PreviewURL)
		if strings.TrimSpace(values["photoURLs"]) == "" {
			assign("photoURLs", metadataValue(detail.Metadata, "プレビュー"))
		}
	}

	switch kind {
	case admincatalog.KindTemplates:
		if strings.TrimSpace(values["svgPath"]) == "" {
			if v := metadataValue(detail.Metadata, "SVG"); strings.TrimSpace(v) != "" && strings.TrimSpace(v) != "未設定" {
				assign("svgPath", v)
			}
		}
	case admincatalog.KindFonts:
		if strings.TrimSpace(values["fontFamily"]) == "" {
			assign("fontFamily", detail.Item.Name)
		}
		if strings.TrimSpace(values["fontWeights"]) == "" {
			if metric := metricValue(detail.Item.Metrics, "ウェイト"); metric != "" {
				if csv := canonicalCSVList(metric); csv != "" {
					assign("fontWeights", csv)
				}
			}
		}
		if strings.TrimSpace(values["license"]) == "" {
			assign("license", metadataValue(detail.Metadata, "ライセンス"))
		}
	case admincatalog.KindMaterials:
		if strings.TrimSpace(values["materialSKU"]) == "" {
			assign("materialSKU", metadataValue(detail.Metadata, "SKU"))
		}
		if strings.TrimSpace(values["color"]) == "" {
			assign("color", metadataValue(detail.Metadata, "カラー"))
		}
		if strings.TrimSpace(values["inventory"]) == "" {
			if meta := metadataValue(detail.Metadata, "在庫"); meta != "" {
				if digits := extractDigits(meta); digits != "" {
					assign("inventory", digits)
				}
			} else if metric := metricValue(detail.Item.Metrics, "在庫"); metric != "" {
				if digits := extractDigits(metric); digits != "" {
					assign("inventory", digits)
				}
			}
		}
	case admincatalog.KindProducts:
		if strings.TrimSpace(values["productSKU"]) == "" {
			assign("productSKU", metadataValue(detail.Metadata, "SKU"))
		}
		if strings.TrimSpace(values["price"]) == "" {
			if metric := metricValue(detail.Item.Metrics, "単価"); metric != "" {
				if digits := extractDigits(metric); digits != "" {
					assign("price", digits)
				}
			} else if meta := metadataValue(detail.Metadata, "価格"); meta != "" {
				if digits := extractDigits(meta); digits != "" {
					assign("price", digits)
				}
			}
		}
		if strings.TrimSpace(values["leadTime"]) == "" {
			if metric := metricValue(detail.Item.Metrics, "リードタイム"); metric != "" {
				if digits := extractDigits(metric); digits != "" {
					assign("leadTime", digits)
				}
			} else if meta := metadataValue(detail.Metadata, "リードタイム"); meta != "" {
				if digits := extractDigits(meta); digits != "" {
					assign("leadTime", digits)
				}
			}
		}
		if strings.TrimSpace(values["photoURLs"]) == "" {
			assign("photoURLs", metadataValue(detail.Metadata, "プレビュー"))
		}
	}

	return values
}

func catalogFormValues(kind admincatalog.Kind, form url.Values) map[string]string {
	values := defaultCatalogValues(kind)
	if form == nil {
		return values
	}
	for key, data := range form {
		if len(data) == 0 {
			values[key] = ""
			continue
		}
		joined := data[len(data)-1]
		if key == "photoURLs" || key == "description" {
			values[key] = strings.TrimRight(joined, "\r\n ")
			continue
		}
		values[key] = strings.TrimSpace(joined)
	}
	return values
}

func buildModalSections(kind admincatalog.Kind, values map[string]string, fieldErrors map[string]string) []catalogtpl.ModalSectionData {
	specs := catalogFieldSpecs(kind)
	sections := map[string][]catalogtpl.ModalFieldData{}
	order := []string{}
	for _, spec := range specs {
		section := spec.Section
		if section == "" {
			section = "基本情報"
		}
		if _, ok := sections[section]; !ok {
			order = append(order, section)
		}
		field := catalogtpl.ModalFieldData{
			Name:         spec.Name,
			Label:        spec.Label,
			Type:         spec.Type,
			Value:        strings.TrimSpace(values[spec.Name]),
			Placeholder:  spec.Placeholder,
			Hint:         spec.Hint,
			Required:     spec.Required,
			FullWidth:    spec.FullWidth,
			Rows:         spec.Rows,
			InputMode:    spec.InputMode,
			Prefix:       spec.Prefix,
			Suffix:       spec.Suffix,
			Autocomplete: spec.Autocomplete,
			Error:        fieldErrors[spec.Name],
		}
		if len(spec.Options) > 0 {
			options := make([]catalogtpl.ModalOptionData, 0, len(spec.Options))
			for _, option := range spec.Options {
				options = append(options, catalogtpl.ModalOptionData{
					Value:    option.Value,
					Label:    option.Label,
					Selected: strings.TrimSpace(values[spec.Name]) == option.Value,
				})
			}
			field.Options = options
		}
		if spec.Asset != nil {
			assetIDField := firstNonEmpty(spec.Asset.AssetIDField, spec.Name)
			assetID := strings.TrimSpace(values[assetIDField])
			field.Asset = &catalogtpl.ModalAssetField{
				Purpose:        spec.Asset.Purpose,
				Kind:           spec.Asset.Kind,
				Accept:         spec.Asset.Accept,
				MaxSizeBytes:   spec.Asset.MaxSize,
				AssetIDName:    assetIDField,
				AssetID:        assetID,
				AssetURL:       strings.TrimSpace(values[spec.Asset.URLField]),
				FileName:       strings.TrimSpace(values[spec.Asset.FileNameField]),
				FileNameName:   spec.Asset.FileNameField,
				URLFieldName:   spec.Asset.URLField,
				URLFieldValue:  strings.TrimSpace(values[spec.Asset.URLField]),
				DisplayPreview: spec.Asset.DisplayPreview,
				UploadLabel:    firstNonEmpty(spec.Asset.UploadLabel, "ファイルを選択"),
				ReplaceLabel:   firstNonEmpty(spec.Asset.ReplaceLabel, "別のファイルを選択"),
				RemoveLabel:    firstNonEmpty(spec.Asset.RemoveLabel, "削除"),
				EmptyLabel:     firstNonEmpty(spec.Asset.EmptyLabel, "未設定"),
			}
		}
		sections[section] = append(sections[section], field)
	}
	result := make([]catalogtpl.ModalSectionData, 0, len(order))
	for _, key := range order {
		result = append(result, catalogtpl.ModalSectionData{
			Title:  key,
			Fields: sections[key],
		})
	}
	return result
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func catalogFieldSpecs(kind admincatalog.Kind) []modalFieldSpec {
	base := []modalFieldSpec{
		{Name: "name", Label: "名称", Type: "text", Section: "基本情報", Placeholder: "例: プレミアム年賀状", Required: true, FullWidth: true},
		{Name: "identifier", Label: "識別子", Type: "text", Section: "基本情報", Placeholder: "例: TMP-2024-FUJI", Required: true},
		{Name: "status", Label: "ステータス", Type: "select", Section: "基本情報", Required: true, Options: statusOptions()},
		{Name: "category", Label: "カテゴリ", Type: "select", Section: "基本情報", Options: categoryOptions(kind)},
		{Name: "tags", Label: "タグ", Type: "text", Section: "基本情報", Hint: "カンマ区切りで指定", FullWidth: true},
		{Name: "description", Label: "説明", Type: "textarea", Section: "基本情報", Rows: 3, Required: true, FullWidth: true},
		{
			Name:      "previewURL",
			Label:     "プレビュー画像",
			Type:      "asset",
			Section:   "基本情報",
			Required:  true,
			FullWidth: true,
			Hint:      "PNG/JPG/WebP 最大5MB",
			Asset: &assetFieldSpec{
				Purpose:        "preview",
				Kind:           "png",
				Accept:         "image/png,image/jpeg,image/webp",
				MaxSize:        5 * 1024 * 1024,
				AssetIDField:   "previewAssetID",
				URLField:       "previewURL",
				FileNameField:  "previewFileName",
				DisplayPreview: true,
				UploadLabel:    "画像をアップロード",
				ReplaceLabel:   "画像を変更",
				RemoveLabel:    "画像を削除",
				EmptyLabel:     "未設定",
			},
		},
		{Name: "primaryColor", Label: "ブランドカラー", Type: "text", Section: "基本情報", Placeholder: "#0F172A"},
		{Name: "ownerName", Label: "担当者", Type: "text", Section: "基本情報", Required: true},
		{Name: "ownerEmail", Label: "担当者メール", Type: "email", Section: "基本情報", Placeholder: "ops@example.com"},
	}
	switch kind {
	case admincatalog.KindFonts:
		base = append(base,
			modalFieldSpec{Name: "fontFamily", Label: "フォントファミリー", Type: "text", Section: "フォント情報", Required: true},
			modalFieldSpec{Name: "fontWeights", Label: "ウェイト", Type: "text", Section: "フォント情報", Hint: "例: 400,700"},
			modalFieldSpec{Name: "license", Label: "ライセンス", Type: "text", Section: "フォント情報", Required: true},
		)
	case admincatalog.KindMaterials:
		base = append(base,
			modalFieldSpec{Name: "materialSKU", Label: "素材SKU", Type: "text", Section: "素材情報", Required: true},
			modalFieldSpec{Name: "color", Label: "カラー", Type: "text", Section: "素材情報"},
			modalFieldSpec{Name: "inventory", Label: "在庫枚数", Type: "number", Section: "素材情報", InputMode: "numeric", Required: true},
		)
	case admincatalog.KindProducts:
		base = append(base,
			modalFieldSpec{Name: "productSKU", Label: "商品SKU", Type: "text", Section: "商品情報", Required: true},
			modalFieldSpec{Name: "price", Label: "価格 (税抜)", Type: "number", Section: "商品情報", InputMode: "numeric", Required: true, Prefix: "¥"},
			modalFieldSpec{Name: "currency", Label: "通貨", Type: "select", Section: "商品情報", Options: currencyOptions(), Required: true},
			modalFieldSpec{Name: "leadTime", Label: "リードタイム", Type: "number", Section: "商品情報", InputMode: "numeric", Required: true, Suffix: "日"},
			modalFieldSpec{Name: "photoURLs", Label: "画像URL", Type: "textarea", Section: "商品情報", Rows: 3, Hint: "複数行で指定", FullWidth: true},
		)
	default:
		base = append(base,
			modalFieldSpec{Name: "templateID", Label: "テンプレートID", Type: "text", Section: "テンプレート情報", Required: true},
			modalFieldSpec{
				Name:      "svgPath",
				Label:     "SVG デザイン",
				Type:      "asset",
				Section:   "テンプレート情報",
				Required:  true,
				FullWidth: true,
				Hint:      "SVG 最大2MB",
				Asset: &assetFieldSpec{
					Purpose:        "design-master",
					Kind:           "svg",
					Accept:         "image/svg+xml",
					MaxSize:        2 * 1024 * 1024,
					AssetIDField:   "svgAssetID",
					URLField:       "svgPath",
					FileNameField:  "svgFileName",
					DisplayPreview: false,
					UploadLabel:    "SVGをアップロード",
					ReplaceLabel:   "SVGを変更",
					RemoveLabel:    "SVGを削除",
					EmptyLabel:     "未設定",
				},
			},
		)
	}
	return base
}

func statusOptions() []modalOptionSpec {
	return []modalOptionSpec{
		{Value: string(admincatalog.StatusDraft), Label: "下書き"},
		{Value: string(admincatalog.StatusInReview), Label: "レビュー"},
		{Value: string(admincatalog.StatusPublished), Label: "公開"},
		{Value: string(admincatalog.StatusArchived), Label: "アーカイブ"},
	}
}

func categoryOptions(kind admincatalog.Kind) []modalOptionSpec {
	switch kind {
	case admincatalog.KindFonts:
		return []modalOptionSpec{{Value: "serif", Label: "セリフ"}, {Value: "sans", Label: "サンセリフ"}, {Value: "script", Label: "スクリプト"}}
	case admincatalog.KindMaterials:
		return []modalOptionSpec{{Value: "textured", Label: "テクスチャ"}, {Value: "matte", Label: "マット"}, {Value: "gloss", Label: "グロス"}}
	case admincatalog.KindProducts:
		return []modalOptionSpec{{Value: "seasonal_bundle", Label: "季節ギフト"}, {Value: "engraving", Label: "名入れ"}, {Value: "cards", Label: "カード"}}
	default:
		return []modalOptionSpec{{Value: "seasonal", Label: "季節"}, {Value: "business", Label: "ビジネス"}, {Value: "family", Label: "ファミリー"}}
	}
}

func currencyOptions() []modalOptionSpec {
	return []modalOptionSpec{
		{Value: "JPY", Label: "JPY"},
		{Value: "USD", Label: "USD"},
	}
}

func resetPlaceholderValues(values map[string]string) {
	for _, key := range []string{
		"templateID",
		"svgPath",
		"svgAssetID",
		"svgFileName",
		"fontFamily",
		"fontWeights",
		"license",
		"materialSKU",
		"color",
		"inventory",
		"productSKU",
		"price",
		"leadTime",
		"photoURLs",
		"previewAssetID",
		"previewFileName",
	} {
		values[key] = ""
	}
}

func normalizeCatalogFormValue(key, value string) string {
	switch key {
	case "photoURLs", "description":
		return strings.TrimRight(value, "\r\n ")
	default:
		return strings.TrimSpace(value)
	}
}

func metadataValue(entries []admincatalog.MetadataEntry, contains string) string {
	needle := strings.ToLower(strings.TrimSpace(contains))
	if needle == "" {
		return ""
	}
	for _, entry := range entries {
		if strings.Contains(strings.ToLower(entry.Key), needle) {
			return strings.TrimSpace(entry.Value)
		}
	}
	return ""
}

func metricValue(metrics []admincatalog.ItemMetric, contains string) string {
	needle := strings.ToLower(strings.TrimSpace(contains))
	if needle == "" {
		return ""
	}
	for _, metric := range metrics {
		if strings.Contains(strings.ToLower(metric.Label), needle) {
			return strings.TrimSpace(metric.Value)
		}
	}
	return ""
}

func extractDigits(value string) string {
	var builder strings.Builder
	for _, r := range value {
		if unicode.IsDigit(r) {
			builder.WriteRune(r)
		}
	}
	return builder.String()
}

func canonicalCSVList(value string) string {
	fields := strings.FieldsFunc(value, func(r rune) bool {
		return r == ',' || r == '、'
	})
	cleaned := make([]string, 0, len(fields))
	for _, field := range fields {
		trimmed := strings.TrimSpace(field)
		if trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	if len(cleaned) == 0 {
		return ""
	}
	return strings.Join(cleaned, ", ")
}
