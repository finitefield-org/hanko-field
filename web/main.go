package main

import (
	"errors"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"
)

var sealLineRegexp = regexp.MustCompile(`^[\p{Han}\p{Hiragana}\p{Katakana}A-Za-z0-9]{1,2}$`)

var shapeLabels = map[string]string{
	"square": "角印",
	"round":  "丸印",
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

type pageData struct {
	Fonts     []fontOption
	Materials []materialOption
}

type kanjiSuggestionData struct {
	RealName    string
	Suggestions []string
}

type purchaseResultData struct {
	Error         string
	SealLine1     string
	SealLine2     string
	FontLabel     string
	ShapeLabel    string
	MaterialLabel string
	Price         int
	Email         string
}

type server struct {
	tmpl          *template.Template
	fonts         []fontOption
	materials     []materialOption
	fontByKey     map[string]fontOption
	materialByKey map[string]materialOption
}

func main() {
	s, err := newServer()
	if err != nil {
		log.Fatalf("failed to initialize web mock: %v", err)
	}

	mux := http.NewServeMux()
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/mock/kanji", s.handleKanjiSuggestions)
	mux.HandleFunc("/mock/purchase", s.handlePurchase)

	port := strings.TrimSpace(os.Getenv("HANKO_WEB_PORT"))
	if port == "" {
		port = "3052"
	}

	addr := ":" + port
	log.Printf("hanko web mock listening on http://localhost%s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func newServer() (*server, error) {
	fonts := []fontOption{
		{Key: "zen_maru_gothic", Label: "Zen Maru Gothic", Family: "'Zen Maru Gothic', sans-serif"},
		{Key: "kosugi_maru", Label: "Kosugi Maru", Family: "'Kosugi Maru', sans-serif"},
		{Key: "potta_one", Label: "Potta One", Family: "'Potta One', sans-serif"},
		{Key: "kiwi_maru", Label: "Kiwi Maru", Family: "'Kiwi Maru', sans-serif"},
		{Key: "wdxl_lubrifont_jp_n", Label: "WDXL Lubrifont JP N", Family: "'WDXL Lubrifont JP N', sans-serif"},
	}

	materials := []materialOption{
		{Key: "boxwood", Label: "柘植", Description: "軽くて扱いやすい定番材", Price: 3600},
		{Key: "black_buffalo", Label: "黒水牛", Description: "しっとりした質感で耐久性が高い", Price: 4800},
		{Key: "titanium", Label: "チタン", Description: "重厚で摩耗に強いプレミアム材", Price: 9800},
	}

	fontByKey := make(map[string]fontOption, len(fonts))
	for _, f := range fonts {
		fontByKey[f.Key] = f
	}

	materialByKey := make(map[string]materialOption, len(materials))
	for _, m := range materials {
		materialByKey[m.Key] = m
	}

	tmpl, err := template.New("index.html").Funcs(template.FuncMap{
		"yen": formatYen,
	}).ParseFiles("templates/index.html")
	if err != nil {
		return nil, err
	}

	return &server{
		tmpl:          tmpl,
		fonts:         fonts,
		materials:     materials,
		fontByKey:     fontByKey,
		materialByKey: materialByKey,
	}, nil
}

func (s *server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	data := pageData{
		Fonts:     s.fonts,
		Materials: s.materials,
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

	sealLine1 := strings.TrimSpace(r.Form.Get("seal_line1"))
	sealLine2 := strings.TrimSpace(r.Form.Get("seal_line2"))
	fontKey := strings.TrimSpace(r.Form.Get("font"))
	shapeKey := strings.TrimSpace(r.Form.Get("shape"))
	materialKey := strings.TrimSpace(r.Form.Get("material"))
	email := strings.TrimSpace(r.Form.Get("email"))

	result := purchaseResultData{}

	if err := validateSealLines(sealLine1, sealLine2); err != nil {
		result.Error = err.Error()
		s.renderPurchaseResult(w, result)
		return
	}

	font, ok := s.fontByKey[fontKey]
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

	material, ok := s.materialByKey[materialKey]
	if !ok {
		result.Error = "材質を選択してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	if email == "" {
		result.Error = "購入確認用のメールアドレスを入力してください。"
		s.renderPurchaseResult(w, result)
		return
	}

	result.SealLine1 = sealLine1
	result.SealLine2 = sealLine2
	result.FontLabel = font.Label
	result.ShapeLabel = shapeLabel
	result.MaterialLabel = material.Label
	result.Price = material.Price
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
		return errors.New("印影テキスト1行目を入力してください。")
	}

	if utf8.RuneCountInString(first) > 2 {
		return errors.New("印影テキスト1行目は2文字以内で入力してください。")
	}

	if utf8.RuneCountInString(second) > 2 {
		return errors.New("印影テキスト2行目は2文字以内で入力してください。")
	}

	if !sealLineRegexp.MatchString(first) {
		return errors.New("1行目で使える文字は漢字・ひらがな・カタカナ・英字・数字のみです。")
	}

	if second != "" && !sealLineRegexp.MatchString(second) {
		return errors.New("2行目で使える文字は漢字・ひらがな・カタカナ・英字・数字のみです。")
	}

	return nil
}

func suggestKanjiCandidates(realName string) []string {
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

	results := make([]string, 0, 3)
	seen := map[string]struct{}{}
	for i := 0; len(results) < 3 && i < 24; i++ {
		candidate := prefixes[(sum+i*2)%len(prefixes)] + suffixes[(sum+i*3)%len(suffixes)]
		if utf8.RuneCountInString(candidate) > 4 {
			continue
		}
		if _, exists := seen[candidate]; exists {
			continue
		}
		seen[candidate] = struct{}{}
		results = append(results, candidate)
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
