package main

import (
	"context"
	"errors"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

var shapeLabels = map[string]string{
	"square": "角印",
	"round":  "丸印",
}

type runMode string

const (
	runModeMock runMode = "mock"
	runModeDev  runMode = "dev"
	runModeProd runMode = "prod"
)

type appConfig struct {
	Port               string
	Mode               runMode
	Locale             string
	DefaultLocale      string
	FirestoreProjectID string
	CredentialsFile    string
}

type fontOption struct {
	Key    string
	Label  string
	Family string
}

type materialOption struct {
	Key         string
	Label       string
	Description string
	Price       int
}

type countryOption struct {
	Code     string
	Label    string
	Shipping int
}

type catalogData struct {
	Fonts     []fontOption
	Materials []materialOption
	Countries []countryOption
}

type pageData struct {
	Fonts       []fontOption
	Materials   []materialOption
	Countries   []countryOption
	SourceLabel string
	IsMock      bool
}

type kanjiSuggestionData struct {
	RealName    string
	Suggestions []kanjiCandidate
}

type kanjiCandidate struct {
	Label  string
	Line1  string
	Line2  string
	Reason string
}

type purchaseResultData struct {
	Error         string
	SealLine1     string
	SealLine2     string
	FontLabel     string
	ShapeLabel    string
	MaterialLabel string
	StripeName    string
	StripePhone   string
	CountryLabel  string
	PostalCode    string
	State         string
	City          string
	AddressLine1  string
	AddressLine2  string
	Subtotal      int
	Shipping      int
	Total         int
	Email         string
	SourceLabel   string
	IsMock        bool
}

type catalogSource interface {
	LoadCatalog(ctx context.Context) (catalogData, error)
	Close() error
	Label() string
	IsMock() bool
}

type mockCatalogSource struct {
	catalog catalogData
}

type firestoreCatalogSource struct {
	client        *firestore.Client
	locale        string
	defaultLocale string
	label         string
}

type server struct {
	tmpl   *template.Template
	source catalogSource
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	s, err := newServer(cfg)
	if err != nil {
		log.Fatalf("failed to initialize web server: %v", err)
	}
	defer func() {
		if err := s.Close(); err != nil {
			log.Printf("failed to close server resources: %v", err)
		}
	}()

	mux := http.NewServeMux()
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/kanji", s.handleKanjiSuggestions)
	mux.HandleFunc("/purchase", s.handlePurchase)

	// Backward compatibility for existing mock endpoints.
	mux.HandleFunc("/mock/kanji", s.handleKanjiSuggestions)
	mux.HandleFunc("/mock/purchase", s.handlePurchase)

	addr := ":" + cfg.Port
	if cfg.FirestoreProjectID == "" {
		log.Printf("hanko web listening on http://localhost%s mode=%s source=%s locale=%s", addr, cfg.Mode, s.source.Label(), cfg.Locale)
	} else {
		log.Printf(
			"hanko web listening on http://localhost%s mode=%s source=%s project=%s locale=%s",
			addr,
			cfg.Mode,
			s.source.Label(),
			cfg.FirestoreProjectID,
			cfg.Locale,
		)
	}

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func loadConfig() (appConfig, error) {
	cfg := appConfig{
		Port:          strings.TrimSpace(os.Getenv("HANKO_WEB_PORT")),
		Locale:        strings.TrimSpace(os.Getenv("HANKO_WEB_LOCALE")),
		DefaultLocale: strings.TrimSpace(os.Getenv("HANKO_WEB_DEFAULT_LOCALE")),
	}

	if cfg.Port == "" {
		cfg.Port = "3052"
	}

	if cfg.Locale == "" {
		cfg.Locale = "ja"
	}

	if cfg.DefaultLocale == "" {
		cfg.DefaultLocale = "ja"
	}

	modeValue := strings.ToLower(strings.TrimSpace(envFirst("HANKO_WEB_MODE", "HANKO_WEB_ENV")))
	if modeValue == "" {
		modeValue = string(runModeMock)
	}

	switch runMode(modeValue) {
	case runModeMock:
		cfg.Mode = runModeMock
		return cfg, nil
	case runModeDev:
		cfg.Mode = runModeDev
	case runModeProd:
		cfg.Mode = runModeProd
	default:
		return appConfig{}, fmt.Errorf("invalid HANKO_WEB_MODE %q: use mock, dev, or prod", modeValue)
	}

	projectIDKeys := []string{}
	credentialsKeys := []string{}

	switch cfg.Mode {
	case runModeDev:
		projectIDKeys = []string{
			"HANKO_WEB_FIREBASE_PROJECT_ID_DEV",
			"HANKO_WEB_FIREBASE_PROJECT_ID",
			"FIREBASE_PROJECT_ID",
			"GOOGLE_CLOUD_PROJECT",
		}
		credentialsKeys = []string{
			"HANKO_WEB_FIREBASE_CREDENTIALS_FILE_DEV",
			"HANKO_WEB_FIREBASE_CREDENTIALS_FILE",
			"GOOGLE_APPLICATION_CREDENTIALS",
		}
	case runModeProd:
		projectIDKeys = []string{
			"HANKO_WEB_FIREBASE_PROJECT_ID_PROD",
			"HANKO_WEB_FIREBASE_PROJECT_ID",
			"FIREBASE_PROJECT_ID",
			"GOOGLE_CLOUD_PROJECT",
		}
		credentialsKeys = []string{
			"HANKO_WEB_FIREBASE_CREDENTIALS_FILE_PROD",
			"HANKO_WEB_FIREBASE_CREDENTIALS_FILE",
			"GOOGLE_APPLICATION_CREDENTIALS",
		}
	}

	cfg.FirestoreProjectID = envFirst(projectIDKeys...)
	if cfg.FirestoreProjectID == "" {
		return appConfig{}, fmt.Errorf("firebase mode (%s) requires project id env var: %s", cfg.Mode, strings.Join(projectIDKeys, ", "))
	}

	cfg.CredentialsFile = envFirst(credentialsKeys...)
	return cfg, nil
}

func envFirst(keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return value
		}
	}
	return ""
}

func newServer(cfg appConfig) (*server, error) {
	tmpl, err := template.New("index.html").Funcs(template.FuncMap{
		"yen": formatYen,
	}).ParseFiles("templates/index.html")
	if err != nil {
		return nil, err
	}

	source, err := newCatalogSource(cfg)
	if err != nil {
		return nil, err
	}

	s := &server{
		tmpl:   tmpl,
		source: source,
	}

	if _, err := s.loadCatalog(context.Background()); err != nil {
		_ = source.Close()
		return nil, err
	}

	return s, nil
}

func newCatalogSource(cfg appConfig) (catalogSource, error) {
	switch cfg.Mode {
	case runModeMock:
		return newMockCatalogSource(), nil
	case runModeDev, runModeProd:
		label := "Firebase Dev"
		if cfg.Mode == runModeProd {
			label = "Firebase Prod"
		}

		clientOptions := []option.ClientOption{}
		if cfg.CredentialsFile != "" {
			clientOptions = append(clientOptions, option.WithCredentialsFile(cfg.CredentialsFile))
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		client, err := firestore.NewClient(ctx, cfg.FirestoreProjectID, clientOptions...)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize firestore client: %w", err)
		}

		return &firestoreCatalogSource{
			client:        client,
			locale:        cfg.Locale,
			defaultLocale: cfg.DefaultLocale,
			label:         label,
		}, nil
	default:
		return nil, fmt.Errorf("unsupported mode: %s", cfg.Mode)
	}
}

func newMockCatalogSource() *mockCatalogSource {
	return &mockCatalogSource{
		catalog: catalogData{
			Fonts: []fontOption{
				{Key: "zen_maru_gothic", Label: "Zen Maru Gothic", Family: "'Zen Maru Gothic', sans-serif"},
				{Key: "kosugi_maru", Label: "Kosugi Maru", Family: "'Kosugi Maru', sans-serif"},
				{Key: "potta_one", Label: "Potta One", Family: "'Potta One', sans-serif"},
				{Key: "kiwi_maru", Label: "Kiwi Maru", Family: "'Kiwi Maru', sans-serif"},
				{Key: "wdxl_lubrifont_jp_n", Label: "WDXL Lubrifont JP N", Family: "'WDXL Lubrifont JP N', sans-serif"},
			},
			Materials: []materialOption{
				{Key: "boxwood", Label: "柘植", Description: "軽くて扱いやすい定番材", Price: 3600},
				{Key: "black_buffalo", Label: "黒水牛", Description: "しっとりした質感で耐久性が高い", Price: 4800},
				{Key: "titanium", Label: "チタン", Description: "重厚で摩耗に強いプレミアム材", Price: 9800},
			},
			Countries: []countryOption{
				{Code: "JP", Label: "日本", Shipping: 600},
				{Code: "US", Label: "アメリカ", Shipping: 1800},
				{Code: "CA", Label: "カナダ", Shipping: 1900},
				{Code: "GB", Label: "イギリス", Shipping: 2000},
				{Code: "AU", Label: "オーストラリア", Shipping: 2100},
				{Code: "SG", Label: "シンガポール", Shipping: 1300},
			},
		},
	}
}

func (s *mockCatalogSource) LoadCatalog(ctx context.Context) (catalogData, error) {
	select {
	case <-ctx.Done():
		return catalogData{}, ctx.Err()
	default:
	}
	return cloneCatalog(s.catalog), nil
}

func (s *mockCatalogSource) Close() error {
	return nil
}

func (s *mockCatalogSource) Label() string {
	return "Mock"
}

func (s *mockCatalogSource) IsMock() bool {
	return true
}

func (s *firestoreCatalogSource) LoadCatalog(ctx context.Context) (catalogData, error) {
	fonts, err := s.loadFonts(ctx)
	if err != nil {
		return catalogData{}, err
	}

	materials, err := s.loadMaterials(ctx)
	if err != nil {
		return catalogData{}, err
	}

	countries, err := s.loadCountries(ctx)
	if err != nil {
		return catalogData{}, err
	}

	return catalogData{
		Fonts:     fonts,
		Materials: materials,
		Countries: countries,
	}, nil
}

func (s *firestoreCatalogSource) Close() error {
	return s.client.Close()
}

func (s *firestoreCatalogSource) Label() string {
	return s.label
}

func (s *firestoreCatalogSource) IsMock() bool {
	return false
}

func (s *firestoreCatalogSource) loadFonts(ctx context.Context) ([]fontOption, error) {
	iter := s.client.Collection("fonts").Where("is_active", "==", true).OrderBy("sort_order", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	fonts := []fontOption{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load fonts: %w", err)
		}

		data := doc.Data()
		family := readStringField(data, "font_family")
		if family == "" {
			family = readStringField(data, "family")
		}
		if family == "" {
			return nil, fmt.Errorf("fonts/%s is missing font_family", doc.Ref.ID)
		}

		label := resolveLocalizedField(data, "label_i18n", "label", s.locale, s.defaultLocale, doc.Ref.ID)
		fonts = append(fonts, fontOption{
			Key:    doc.Ref.ID,
			Label:  label,
			Family: family,
		})
	}

	if len(fonts) == 0 {
		return nil, errors.New("no active fonts found in firestore")
	}

	return fonts, nil
}

func (s *firestoreCatalogSource) loadMaterials(ctx context.Context) ([]materialOption, error) {
	iter := s.client.Collection("materials").Where("is_active", "==", true).OrderBy("sort_order", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	materials := []materialOption{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load materials: %w", err)
		}

		data := doc.Data()
		price, ok := readIntField(data, "price_jpy")
		if !ok {
			price, ok = readIntField(data, "price")
		}
		if !ok {
			return nil, fmt.Errorf("materials/%s is missing price_jpy", doc.Ref.ID)
		}

		label := resolveLocalizedField(data, "label_i18n", "label", s.locale, s.defaultLocale, doc.Ref.ID)
		description := resolveLocalizedField(data, "description_i18n", "description", s.locale, s.defaultLocale, "")

		materials = append(materials, materialOption{
			Key:         doc.Ref.ID,
			Label:       label,
			Description: description,
			Price:       price,
		})
	}

	if len(materials) == 0 {
		return nil, errors.New("no active materials found in firestore")
	}

	return materials, nil
}

func (s *firestoreCatalogSource) loadCountries(ctx context.Context) ([]countryOption, error) {
	iter := s.client.Collection("countries").Where("is_active", "==", true).OrderBy("sort_order", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	countries := []countryOption{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load countries: %w", err)
		}

		data := doc.Data()
		shipping, ok := readIntField(data, "shipping_fee_jpy")
		if !ok {
			shipping, ok = readIntField(data, "shipping")
		}
		if !ok {
			return nil, fmt.Errorf("countries/%s is missing shipping_fee_jpy", doc.Ref.ID)
		}

		label := resolveLocalizedField(data, "label_i18n", "label", s.locale, s.defaultLocale, doc.Ref.ID)
		countries = append(countries, countryOption{
			Code:     doc.Ref.ID,
			Label:    label,
			Shipping: shipping,
		})
	}

	if len(countries) == 0 {
		return nil, errors.New("no active countries found in firestore")
	}

	return countries, nil
}

func (s *server) Close() error {
	if s.source == nil {
		return nil
	}
	return s.source.Close()
}

func (s *server) loadCatalog(ctx context.Context) (catalogData, error) {
	loadCtx, cancel := context.WithTimeout(ctx, 7*time.Second)
	defer cancel()

	catalog, err := s.source.LoadCatalog(loadCtx)
	if err != nil {
		return catalogData{}, err
	}

	if err := validateCatalog(catalog); err != nil {
		return catalogData{}, err
	}

	return catalog, nil
}

func validateCatalog(catalog catalogData) error {
	if len(catalog.Fonts) == 0 {
		return errors.New("catalog validation failed: fonts is empty")
	}
	if len(catalog.Materials) == 0 {
		return errors.New("catalog validation failed: materials is empty")
	}
	if len(catalog.Countries) == 0 {
		return errors.New("catalog validation failed: countries is empty")
	}
	return nil
}

func cloneCatalog(c catalogData) catalogData {
	return catalogData{
		Fonts:     append([]fontOption(nil), c.Fonts...),
		Materials: append([]materialOption(nil), c.Materials...),
		Countries: append([]countryOption(nil), c.Countries...),
	}
}

func (s *server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	catalog, err := s.loadCatalog(r.Context())
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to load catalog: %v", err), http.StatusInternalServerError)
		return
	}

	data := pageData{
		Fonts:       catalog.Fonts,
		Materials:   catalog.Materials,
		Countries:   catalog.Countries,
		SourceLabel: s.source.Label(),
		IsMock:      s.source.IsMock(),
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := s.tmpl.ExecuteTemplate(w, "page", data); err != nil {
		http.Error(w, fmt.Sprintf("failed to render page: %v", err), http.StatusInternalServerError)
	}
}

func (s *server) handleKanjiSuggestions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	realName := strings.TrimSpace(r.Form.Get("real_name"))
	data := kanjiSuggestionData{
		RealName:    realName,
		Suggestions: suggestKanjiCandidates(realName),
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := s.tmpl.ExecuteTemplate(w, "kanji_suggestions", data); err != nil {
		http.Error(w, fmt.Sprintf("failed to render suggestions: %v", err), http.StatusInternalServerError)
	}
}

func (s *server) handlePurchase(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	catalog, err := s.loadCatalog(r.Context())
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to load catalog: %v", err), http.StatusInternalServerError)
		return
	}

	fontByKey := make(map[string]fontOption, len(catalog.Fonts))
	for _, f := range catalog.Fonts {
		fontByKey[f.Key] = f
	}

	materialByKey := make(map[string]materialOption, len(catalog.Materials))
	for _, m := range catalog.Materials {
		materialByKey[m.Key] = m
	}

	countryByCode := make(map[string]countryOption, len(catalog.Countries))
	for _, c := range catalog.Countries {
		countryByCode[c.Code] = c
	}

	sealLine1 := strings.TrimSpace(r.Form.Get("seal_line1"))
	sealLine2 := strings.TrimSpace(r.Form.Get("seal_line2"))
	fontKey := strings.TrimSpace(r.Form.Get("font"))
	shapeKey := strings.TrimSpace(r.Form.Get("shape"))
	materialKey := strings.TrimSpace(r.Form.Get("material"))
	recipientName := strings.TrimSpace(r.Form.Get("recipient_name"))
	phone := strings.TrimSpace(r.Form.Get("phone"))
	countryCode := strings.TrimSpace(r.Form.Get("country"))
	postalCode := strings.TrimSpace(r.Form.Get("postal_code"))
	state := strings.TrimSpace(r.Form.Get("state"))
	city := strings.TrimSpace(r.Form.Get("city"))
	addressLine1 := strings.TrimSpace(r.Form.Get("address_line1"))
	addressLine2 := strings.TrimSpace(r.Form.Get("address_line2"))
	email := strings.TrimSpace(r.Form.Get("email"))
	termsValue := strings.TrimSpace(r.Form.Get("terms_agreed"))
	termsAgreed := termsValue == "on" || termsValue == "1" || strings.EqualFold(termsValue, "true")

	result := purchaseResultData{
		SourceLabel: s.source.Label(),
		IsMock:      s.source.IsMock(),
	}

	if err := validateSealLines(sealLine1, sealLine2); err != nil {
		result.Error = err.Error()
		s.renderPurchaseResult(w, result)
		return
	}

	font, ok := fontByKey[fontKey]
	if !ok {
		result.Error = "フォントを選択してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	shapeLabel, ok := shapeLabels[shapeKey]
	if !ok {
		result.Error = "印鑑の形状を選択してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	material, ok := materialByKey[materialKey]
	if !ok {
		result.Error = "材質を選択してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	country, ok := countryByCode[countryCode]
	if !ok {
		result.Error = "配送先の国を選択してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if recipientName == "" {
		result.Error = "購入者名を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if phone == "" {
		result.Error = "電話番号を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if postalCode == "" {
		result.Error = "郵便番号を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if state == "" {
		result.Error = "都道府県 / 州を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if city == "" {
		result.Error = "市区町村 / City を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if addressLine1 == "" {
		result.Error = "住所1を入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if email == "" {
		result.Error = "購入確認用のメールアドレスを入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if !termsAgreed {
		result.Error = "利用規約への同意が必要です。"
		s.renderPurchaseResult(w, result)
		return
	}

	subtotal := material.Price
	shipping := country.Shipping

	result.SealLine1 = sealLine1
	result.SealLine2 = sealLine2
	result.FontLabel = font.Label
	result.ShapeLabel = shapeLabel
	result.MaterialLabel = material.Label
	result.StripeName = recipientName
	result.StripePhone = phone
	result.CountryLabel = country.Label
	result.PostalCode = postalCode
	result.State = state
	result.City = city
	result.AddressLine1 = addressLine1
	result.AddressLine2 = addressLine2
	result.Subtotal = subtotal
	result.Shipping = shipping
	result.Total = subtotal + shipping
	result.Email = email

	s.renderPurchaseResult(w, result)
}

func (s *server) renderPurchaseResult(w http.ResponseWriter, data purchaseResultData) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := s.tmpl.ExecuteTemplate(w, "purchase_result", data); err != nil {
		http.Error(w, fmt.Sprintf("failed to render purchase result: %v", err), http.StatusInternalServerError)
	}
}

func validateSealLines(line1, line2 string) error {
	first := strings.TrimSpace(line1)
	second := strings.TrimSpace(line2)

	if first == "" {
		return errors.New("お名前を入力してください。")
	}

	if containsWhitespace(first) {
		return errors.New("1行目に空白は使えません。")
	}

	if second != "" && containsWhitespace(second) {
		return errors.New("2行目に空白は使えません。")
	}

	if utf8.RuneCountInString(first) > 2 {
		return errors.New("印影テキスト1行目は2文字以内で入力してください。")
	}

	if utf8.RuneCountInString(second) > 2 {
		return errors.New("印影テキスト2行目は2文字以内で入力してください。")
	}

	return nil
}

func containsWhitespace(value string) bool {
	return strings.IndexFunc(value, unicode.IsSpace) >= 0
}

func suggestKanjiCandidates(realName string) []kanjiCandidate {
	name := strings.TrimSpace(realName)
	if name == "" {
		return nil
	}

	prefixes := []string{"蒼", "悠", "和", "紬", "凛", "奏", "晴", "結", "明", "直"}
	suffixes := []string{"真", "希", "翔", "音", "花", "斗", "香", "雅", "心", "人"}

	sum := 0
	for _, r := range []rune(strings.ToLower(name)) {
		sum += int(r)
	}

	baseCandidates := make([]string, 0, 3)
	seen := map[string]struct{}{}
	for i := 0; len(baseCandidates) < 3 && i < 24; i++ {
		candidate := prefixes[(sum+i*2)%len(prefixes)] + suffixes[(sum+i*3)%len(suffixes)]
		if utf8.RuneCountInString(candidate) > 4 {
			continue
		}
		if _, exists := seen[candidate]; exists {
			continue
		}
		seen[candidate] = struct{}{}
		baseCandidates = append(baseCandidates, candidate)
	}

	results := make([]kanjiCandidate, 0, len(baseCandidates)*2)
	for _, candidate := range baseCandidates {
		results = append(results, kanjiCandidate{
			Label:  candidate,
			Line1:  candidate,
			Reason: fmt.Sprintf("本名の響きから、印影としてまとまりが出る2文字名「%s」を提案しました。", candidate),
		})

		runes := []rune(candidate)
		if len(runes) >= 2 {
			line1 := string(runes[0])
			line2 := string(runes[1])
			results = append(results, kanjiCandidate{
				Label:  line1 + "\n" + line2,
				Line1:  line1,
				Line2:  line2,
				Reason: fmt.Sprintf("「%s」と「%s」を1文字ずつ縦に配置する想定です。視認性が高く、印影のバランスが取りやすい構成です。", line1, line2),
			})
		}
	}

	return results
}

func formatYen(price int) string {
	if price == 0 {
		return "0"
	}

	n := strconv.Itoa(price)
	var out []byte
	for i := 0; i < len(n); i++ {
		if i > 0 && (len(n)-i)%3 == 0 {
			out = append(out, ',')
		}
		out = append(out, n[i])
	}
	return string(out)
}

func resolveLocalizedField(
	data map[string]interface{},
	i18nField string,
	legacyField string,
	locale string,
	defaultLocale string,
	fallback string,
) string {
	if value := resolveLocalizedText(readStringMapField(data, i18nField), locale, defaultLocale); value != "" {
		return value
	}

	if legacyField != "" {
		if value := readStringField(data, legacyField); value != "" {
			return value
		}
	}

	return fallback
}

func resolveLocalizedText(values map[string]string, locale, defaultLocale string) string {
	if len(values) == 0 {
		return ""
	}

	lookup := func(target string) string {
		target = strings.ToLower(strings.TrimSpace(target))
		if target == "" {
			return ""
		}

		for key, value := range values {
			if strings.ToLower(strings.TrimSpace(key)) == target {
				if trimmed := strings.TrimSpace(value); trimmed != "" {
					return trimmed
				}
			}
		}

		if i := strings.Index(target, "-"); i > 0 {
			base := target[:i]
			for key, value := range values {
				if strings.ToLower(strings.TrimSpace(key)) == base {
					if trimmed := strings.TrimSpace(value); trimmed != "" {
						return trimmed
					}
				}
			}
		}

		return ""
	}

	if value := lookup(locale); value != "" {
		return value
	}
	if value := lookup(defaultLocale); value != "" {
		return value
	}
	if value := lookup("ja"); value != "" {
		return value
	}

	keys := make([]string, 0, len(values))
	for key, value := range values {
		if strings.TrimSpace(value) != "" {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return ""
	}

	return strings.TrimSpace(values[keys[0]])
}

func readStringField(data map[string]interface{}, key string) string {
	raw, ok := data[key]
	if !ok || raw == nil {
		return ""
	}

	switch value := raw.(type) {
	case string:
		return strings.TrimSpace(value)
	default:
		return ""
	}
}

func readIntField(data map[string]interface{}, key string) (int, bool) {
	raw, ok := data[key]
	if !ok || raw == nil {
		return 0, false
	}

	switch value := raw.(type) {
	case int:
		return value, true
	case int32:
		return int(value), true
	case int64:
		return int(value), true
	case float32:
		return int(value), true
	case float64:
		return int(value), true
	default:
		return 0, false
	}
}

func readStringMapField(data map[string]interface{}, key string) map[string]string {
	raw, ok := data[key]
	if !ok || raw == nil {
		return nil
	}

	result := map[string]string{}
	switch value := raw.(type) {
	case map[string]string:
		for mapKey, mapValue := range value {
			if trimmed := strings.TrimSpace(mapValue); trimmed != "" {
				result[mapKey] = trimmed
			}
		}
	case map[string]interface{}:
		for mapKey, mapValue := range value {
			if text, ok := mapValue.(string); ok {
				if trimmed := strings.TrimSpace(text); trimmed != "" {
					result[mapKey] = trimmed
				}
			}
		}
	}

	if len(result) == 0 {
		return nil
	}

	return result
}
