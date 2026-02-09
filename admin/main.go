package main

import (
	"context"
	"errors"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var orderStatusLabels = map[string]string{
	"pending_payment": "支払い待ち",
	"paid":            "支払い済み",
	"manufacturing":   "製造中",
	"shipped":         "出荷済み",
	"delivered":       "配達完了",
	"canceled":        "キャンセル",
	"refunded":        "返金済み",
}

var paymentStatusLabels = map[string]string{
	"unpaid":     "未払い",
	"processing": "処理中",
	"paid":       "支払い済み",
	"failed":     "失敗",
	"refunded":   "返金済み",
}

var fulfillmentStatusLabels = map[string]string{
	"pending":       "未着手",
	"manufacturing": "製造中",
	"shipped":       "出荷済み",
	"delivered":     "配達完了",
}

var statusTransitions = map[string][]string{
	"pending_payment": {"paid", "canceled"},
	"paid":            {"manufacturing", "refunded"},
	"manufacturing":   {"shipped", "refunded"},
	"shipped":         {"delivered", "refunded"},
	"delivered":       {},
	"canceled":        {},
	"refunded":        {},
}

type server struct {
	tmpl *template.Template

	mu sync.RWMutex

	mode        runMode
	sourceLabel string
	firestore   *firestoreAdminSource

	orders      map[string]*order
	orderIDs    []string
	materials   map[string]*material
	materialIDs []string
	countries   map[string]string
}

type order struct {
	ID                string
	OrderNo           string
	Channel           string
	Locale            string
	Status            string
	StatusUpdatedAt   time.Time
	PaymentStatus     string
	FulfillmentStatus string
	TrackingNo        string
	Carrier           string
	CountryCode       string
	ContactEmail      string
	SealLine1         string
	SealLine2         string
	MaterialLabelJA   string
	TotalJPY          int
	CreatedAt         time.Time
	UpdatedAt         time.Time
	Events            []orderEvent
}

type orderEvent struct {
	Type         string
	ActorType    string
	ActorID      string
	BeforeStatus string
	AfterStatus  string
	Note         string
	CreatedAt    time.Time
}

type material struct {
	Key             string
	LabelI18N       map[string]string
	DescriptionI18N map[string]string
	PriceJPY        int
	IsActive        bool
	SortOrder       int
	Version         int
	UpdatedAt       time.Time
}

type orderFilter struct {
	Status  string
	Country string
	Email   string
}

type statusOption struct {
	Value string
	Label string
}

type countryOption struct {
	Code  string
	Label string
}

type orderListData struct {
	Orders []orderListItem
}

type orderListItem struct {
	ID                string
	OrderNo           string
	CreatedAt         time.Time
	Status            string
	PaymentStatus     string
	FulfillmentStatus string
	CountryCode       string
	CountryLabel      string
	ContactEmail      string
	TotalJPY          int
}

type orderDetailData struct {
	ID                  string
	OrderNo             string
	CreatedAt           time.Time
	UpdatedAt           time.Time
	Status              string
	StatusUpdatedAt     time.Time
	PaymentStatus       string
	FulfillmentStatus   string
	TrackingNo          string
	Carrier             string
	CountryCode         string
	CountryLabel        string
	ContactEmail        string
	Channel             string
	Locale              string
	SealLine1           string
	SealLine2           string
	MaterialLabelJA     string
	TotalJPY            int
	NextStatuses        []statusOption
	ShippingTransitions []statusOption
	Events              []orderEvent
	Message             string
	Error               string
}

type materialListData struct {
	Materials []materialListItem
}

type materialListItem struct {
	Key       string
	LabelJA   string
	PriceJPY  int
	IsActive  bool
	SortOrder int
	Version   int
	UpdatedAt time.Time
}

type materialDetailData struct {
	Key           string
	LabelJA       string
	LabelEN       string
	DescriptionJA string
	DescriptionEN string
	PriceJPY      int
	IsActive      bool
	SortOrder     int
	Version       int
	UpdatedAt     time.Time
	Message       string
	Error         string
}

type pageData struct {
	Filters        orderFilter
	StatusOptions  []statusOption
	CountryOptions []countryOption
	SourceLabel    string
	IsMock         bool
	OrdersList     orderListData
	OrderDetail    *orderDetailData
	MaterialsList  materialListData
	MaterialDetail *materialDetailData
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	s, err := newServerWithConfig(cfg)
	if err != nil {
		log.Fatalf("failed to initialize admin server: %v", err)
	}
	defer func() {
		if err := s.Close(); err != nil {
			log.Printf("failed to close server resources: %v", err)
		}
	}()

	mux := http.NewServeMux()
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/admin/orders/list", s.handleOrdersList)
	mux.HandleFunc("/admin/orders/", s.handleOrderRoute)
	mux.HandleFunc("/admin/materials/list", s.handleMaterialsList)
	mux.HandleFunc("/admin/materials/", s.handleMaterialRoute)

	addr := cfg.HTTPAddr
	if cfg.FirestoreProjectID == "" {
		log.Printf("hanko admin listening on http://localhost%s mode=%s source=%s", addr, cfg.Mode, s.sourceLabel)
	} else {
		log.Printf(
			"hanko admin listening on http://localhost%s mode=%s source=%s project=%s",
			addr,
			cfg.Mode,
			s.sourceLabel,
			cfg.FirestoreProjectID,
		)
	}

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func newServer() (*server, error) {
	return newServerWithConfig(appConfig{
		HTTPAddr:      ":3051",
		Mode:          runModeMock,
		Locale:        "ja",
		DefaultLocale: "ja",
	})
}

func newMockServer() (*server, error) {
	now := time.Now().UTC()
	orders := map[string]*order{
		"ord_1007": {
			ID:              "ord_1007",
			OrderNo:         "HF-20260209-1007",
			Channel:         "web",
			Locale:          "ja",
			Status:          "manufacturing",
			StatusUpdatedAt: now.Add(-4 * time.Hour),
			CountryCode:     "JP",
			ContactEmail:    "ito@example.com",
			SealLine1:       "伊",
			SealLine2:       "藤",
			MaterialLabelJA: "黒水牛",
			TotalJPY:        5400,
			CreatedAt:       now.Add(-9 * time.Hour),
			UpdatedAt:       now.Add(-4 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "注文を受付", CreatedAt: now.Add(-9 * time.Hour)},
				{Type: "payment_paid", ActorType: "webhook", ActorID: "stripe", BeforeStatus: "pending_payment", AfterStatus: "paid", CreatedAt: now.Add(-6 * time.Hour)},
				{Type: "status_changed", ActorType: "admin", ActorID: "admin.console", BeforeStatus: "paid", AfterStatus: "manufacturing", CreatedAt: now.Add(-4 * time.Hour)},
			},
		},
		"ord_1006": {
			ID:              "ord_1006",
			OrderNo:         "HF-20260209-1006",
			Channel:         "app",
			Locale:          "en",
			Status:          "paid",
			StatusUpdatedAt: now.Add(-2 * time.Hour),
			CountryCode:     "US",
			ContactEmail:    "jane.smith@example.com",
			SealLine1:       "JA",
			SealLine2:       "NE",
			MaterialLabelJA: "チタン",
			TotalJPY:        11600,
			CreatedAt:       now.Add(-12 * time.Hour),
			UpdatedAt:       now.Add(-2 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "Order accepted", CreatedAt: now.Add(-12 * time.Hour)},
				{Type: "payment_paid", ActorType: "webhook", ActorID: "stripe", BeforeStatus: "pending_payment", AfterStatus: "paid", CreatedAt: now.Add(-2 * time.Hour)},
			},
		},
		"ord_1005": {
			ID:              "ord_1005",
			OrderNo:         "HF-20260209-1005",
			Channel:         "web",
			Locale:          "ja",
			Status:          "shipped",
			StatusUpdatedAt: now.Add(-26 * time.Hour),
			CountryCode:     "SG",
			ContactEmail:    "tanaka@example.com",
			SealLine1:       "田",
			SealLine2:       "中",
			MaterialLabelJA: "柘植",
			TotalJPY:        4900,
			TrackingNo:      "SGP-824901",
			Carrier:         "DHL",
			CreatedAt:       now.Add(-36 * time.Hour),
			UpdatedAt:       now.Add(-26 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "注文を受付", CreatedAt: now.Add(-36 * time.Hour)},
				{Type: "payment_paid", ActorType: "webhook", ActorID: "stripe", BeforeStatus: "pending_payment", AfterStatus: "paid", CreatedAt: now.Add(-31 * time.Hour)},
				{Type: "status_changed", ActorType: "admin", ActorID: "admin.console", BeforeStatus: "paid", AfterStatus: "manufacturing", CreatedAt: now.Add(-29 * time.Hour)},
				{Type: "shipment_registered", ActorType: "admin", ActorID: "admin.console", Note: "DHL / SGP-824901", CreatedAt: now.Add(-26 * time.Hour)},
				{Type: "status_changed", ActorType: "admin", ActorID: "admin.console", BeforeStatus: "manufacturing", AfterStatus: "shipped", CreatedAt: now.Add(-26 * time.Hour)},
			},
		},
		"ord_1004": {
			ID:              "ord_1004",
			OrderNo:         "HF-20260208-1004",
			Channel:         "app",
			Locale:          "ja",
			Status:          "delivered",
			StatusUpdatedAt: now.Add(-72 * time.Hour),
			CountryCode:     "JP",
			ContactEmail:    "kato@example.com",
			SealLine1:       "加",
			SealLine2:       "藤",
			MaterialLabelJA: "柘植",
			TotalJPY:        4200,
			TrackingNo:      "YMT-99120",
			Carrier:         "ヤマト運輸",
			CreatedAt:       now.Add(-96 * time.Hour),
			UpdatedAt:       now.Add(-72 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "注文を受付", CreatedAt: now.Add(-96 * time.Hour)},
				{Type: "status_changed", ActorType: "admin", ActorID: "admin.console", BeforeStatus: "shipped", AfterStatus: "delivered", CreatedAt: now.Add(-72 * time.Hour)},
			},
		},
		"ord_1003": {
			ID:              "ord_1003",
			OrderNo:         "HF-20260208-1003",
			Channel:         "web",
			Locale:          "en",
			Status:          "pending_payment",
			StatusUpdatedAt: now.Add(-8 * time.Hour),
			CountryCode:     "CA",
			ContactEmail:    "chris@example.com",
			SealLine1:       "CH",
			SealLine2:       "RI",
			MaterialLabelJA: "チタン",
			TotalJPY:        11800,
			CreatedAt:       now.Add(-30 * time.Hour),
			UpdatedAt:       now.Add(-8 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "Order accepted", CreatedAt: now.Add(-30 * time.Hour)},
			},
		},
		"ord_1002": {
			ID:              "ord_1002",
			OrderNo:         "HF-20260207-1002",
			Channel:         "app",
			Locale:          "ja",
			Status:          "refunded",
			StatusUpdatedAt: now.Add(-130 * time.Hour),
			CountryCode:     "GB",
			ContactEmail:    "suzuki@example.com",
			SealLine1:       "鈴",
			SealLine2:       "木",
			MaterialLabelJA: "黒水牛",
			TotalJPY:        6900,
			TrackingNo:      "GB-12400",
			Carrier:         "Royal Mail",
			CreatedAt:       now.Add(-150 * time.Hour),
			UpdatedAt:       now.Add(-130 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "注文を受付", CreatedAt: now.Add(-150 * time.Hour)},
				{Type: "status_changed", ActorType: "admin", ActorID: "admin.console", BeforeStatus: "shipped", AfterStatus: "refunded", CreatedAt: now.Add(-130 * time.Hour)},
			},
		},
		"ord_1001": {
			ID:              "ord_1001",
			OrderNo:         "HF-20260207-1001",
			Channel:         "web",
			Locale:          "ja",
			Status:          "canceled",
			StatusUpdatedAt: now.Add(-80 * time.Hour),
			CountryCode:     "AU",
			ContactEmail:    "yamada@example.com",
			SealLine1:       "山",
			SealLine2:       "田",
			MaterialLabelJA: "柘植",
			TotalJPY:        5600,
			CreatedAt:       now.Add(-120 * time.Hour),
			UpdatedAt:       now.Add(-80 * time.Hour),
			Events: []orderEvent{
				{Type: "order_created", ActorType: "system", ActorID: "api", Note: "注文を受付", CreatedAt: now.Add(-120 * time.Hour)},
				{Type: "status_changed", ActorType: "system", ActorID: "scheduler", BeforeStatus: "pending_payment", AfterStatus: "canceled", CreatedAt: now.Add(-80 * time.Hour)},
			},
		},
	}

	for _, o := range orders {
		applyDerivedStatuses(o)
	}

	materials := map[string]*material{
		"boxwood": {
			Key: "boxwood",
			LabelI18N: map[string]string{
				"ja": "柘植",
				"en": "Boxwood",
			},
			DescriptionI18N: map[string]string{
				"ja": "軽くて扱いやすい定番材",
				"en": "A standard wood that is lightweight and easy to handle.",
			},
			PriceJPY:  3600,
			IsActive:  true,
			SortOrder: 10,
			Version:   3,
			UpdatedAt: now.Add(-36 * time.Hour),
		},
		"black_buffalo": {
			Key: "black_buffalo",
			LabelI18N: map[string]string{
				"ja": "黒水牛",
				"en": "Black Buffalo",
			},
			DescriptionI18N: map[string]string{
				"ja": "しっとりした質感で耐久性が高い",
				"en": "Durable material with a smooth texture.",
			},
			PriceJPY:  4800,
			IsActive:  true,
			SortOrder: 20,
			Version:   5,
			UpdatedAt: now.Add(-24 * time.Hour),
		},
		"titanium": {
			Key: "titanium",
			LabelI18N: map[string]string{
				"ja": "チタン",
				"en": "Titanium",
			},
			DescriptionI18N: map[string]string{
				"ja": "重厚で摩耗に強いプレミアム材",
				"en": "Premium material with excellent wear resistance.",
			},
			PriceJPY:  9800,
			IsActive:  false,
			SortOrder: 30,
			Version:   2,
			UpdatedAt: now.Add(-12 * time.Hour),
		},
	}

	tmpl, err := newAdminTemplate()
	if err != nil {
		return nil, err
	}

	s := &server{
		tmpl:        tmpl,
		mode:        runModeMock,
		sourceLabel: "Mock",
		orders:      orders,
		materials:   materials,
		countries: map[string]string{
			"JP": "日本",
			"US": "United States",
			"CA": "Canada",
			"GB": "United Kingdom",
			"AU": "Australia",
			"SG": "Singapore",
		},
	}

	s.refreshOrderIDs()
	s.refreshMaterialIDs()

	return s, nil
}

func (s *server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := s.refreshFromSource(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to load admin data: %v", err), http.StatusInternalServerError)
		return
	}

	filters := parseOrderFilter(r)
	orders := s.filterOrders(filters)
	materials := s.listMaterials()

	var detail *orderDetailData
	selectedOrderID := strings.TrimSpace(r.URL.Query().Get("order_id"))
	if selectedOrderID == "" && len(orders) > 0 {
		selectedOrderID = orders[0].ID
	}
	if selectedOrderID != "" {
		if orderDetail, ok := s.getOrderDetail(selectedOrderID, "", ""); ok {
			detail = &orderDetail
		}
	}

	var materialDetail *materialDetailData
	selectedMaterialKey := strings.TrimSpace(r.URL.Query().Get("material_key"))
	if selectedMaterialKey == "" && len(materials.Materials) > 0 {
		selectedMaterialKey = materials.Materials[0].Key
	}
	if selectedMaterialKey != "" {
		if m, ok := s.getMaterialDetail(selectedMaterialKey, "", ""); ok {
			materialDetail = &m
		}
	}

	data := pageData{
		Filters:        filters,
		StatusOptions:  statusOptions(),
		CountryOptions: s.countryOptions(),
		SourceLabel:    s.sourceLabel,
		IsMock:         s.firestore == nil,
		OrdersList: orderListData{
			Orders: orders,
		},
		OrderDetail: detail,
		MaterialsList: materialListData{
			Materials: materials.Materials,
		},
		MaterialDetail: materialDetail,
	}

	s.renderTemplate(w, "page", data)
}

func (s *server) handleOrdersList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := s.refreshFromSource(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to load orders: %v", err), http.StatusInternalServerError)
		return
	}

	filters := parseOrderFilter(r)
	data := orderListData{
		Orders: s.filterOrders(filters),
	}

	s.renderTemplate(w, "orders_list", data)
}

func (s *server) handleOrderRoute(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/admin/orders/")
	path = strings.Trim(path, "/")
	if path == "" {
		http.NotFound(w, r)
		return
	}

	parts := strings.Split(path, "/")
	orderID := strings.TrimSpace(parts[0])
	if orderID == "" {
		http.NotFound(w, r)
		return
	}
	if err := s.refreshFromSource(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to load orders: %v", err), http.StatusInternalServerError)
		return
	}

	switch {
	case r.Method == http.MethodGet && len(parts) == 1:
		detail, ok := s.getOrderDetail(orderID, "", "")
		if !ok {
			http.NotFound(w, r)
			return
		}
		s.renderTemplate(w, "order_detail", detail)
		return
	case r.Method == http.MethodPatch && len(parts) == 2 && parts[1] == "status":
		s.handleOrderStatusPatch(w, r, orderID)
		return
	case r.Method == http.MethodPatch && len(parts) == 2 && parts[1] == "shipping":
		s.handleOrderShippingPatch(w, r, orderID)
		return
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
}

func (s *server) handleOrderStatusPatch(w http.ResponseWriter, r *http.Request, orderID string) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	nextStatus := strings.TrimSpace(r.Form.Get("next_status"))
	actorID := strings.TrimSpace(r.Form.Get("actor_id"))
	if actorID == "" {
		actorID = "admin.console"
	}

	err := s.updateOrderStatusWithContext(r.Context(), orderID, nextStatus, actorID)
	if err != nil {
		detail, ok := s.getOrderDetail(orderID, "", err.Error())
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		s.renderTemplate(w, "order_detail", detail)
		return
	}

	detail, ok := s.getOrderDetail(orderID, "ステータスを更新しました。", "")
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("HX-Trigger", "order-updated")
	s.renderTemplate(w, "order_detail", detail)
}

func (s *server) handleOrderShippingPatch(w http.ResponseWriter, r *http.Request, orderID string) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	carrier := strings.TrimSpace(r.Form.Get("carrier"))
	trackingNo := strings.TrimSpace(r.Form.Get("tracking_no"))
	transition := strings.TrimSpace(r.Form.Get("shipping_transition"))
	actorID := strings.TrimSpace(r.Form.Get("actor_id"))
	if actorID == "" {
		actorID = "admin.console"
	}

	err := s.updateShippingWithContext(r.Context(), orderID, carrier, trackingNo, transition, actorID)
	if err != nil {
		detail, ok := s.getOrderDetail(orderID, "", err.Error())
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		s.renderTemplate(w, "order_detail", detail)
		return
	}

	detail, ok := s.getOrderDetail(orderID, "出荷情報を更新しました。", "")
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("HX-Trigger", "order-updated")
	s.renderTemplate(w, "order_detail", detail)
}

func (s *server) handleMaterialsList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := s.refreshFromSource(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to load materials: %v", err), http.StatusInternalServerError)
		return
	}

	s.renderTemplate(w, "materials_list", s.listMaterials())
}

func (s *server) handleMaterialRoute(w http.ResponseWriter, r *http.Request) {
	materialKey := strings.TrimPrefix(r.URL.Path, "/admin/materials/")
	materialKey = strings.Trim(materialKey, "/")
	if materialKey == "" {
		http.NotFound(w, r)
		return
	}
	if err := s.refreshFromSource(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to load materials: %v", err), http.StatusInternalServerError)
		return
	}

	switch r.Method {
	case http.MethodGet:
		detail, ok := s.getMaterialDetail(materialKey, "", "")
		if !ok {
			http.NotFound(w, r)
			return
		}
		s.renderTemplate(w, "material_detail", detail)
	case http.MethodPatch:
		s.handleMaterialPatch(w, r, materialKey)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *server) handleMaterialPatch(w http.ResponseWriter, r *http.Request, materialKey string) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	price, err := strconv.Atoi(strings.TrimSpace(r.Form.Get("price_jpy")))
	if err != nil {
		detail, ok := s.getMaterialDetail(materialKey, "", "価格は整数で入力してください。")
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		s.renderTemplate(w, "material_detail", detail)
		return
	}

	sortOrder, err := strconv.Atoi(strings.TrimSpace(r.Form.Get("sort_order")))
	if err != nil {
		detail, ok := s.getMaterialDetail(materialKey, "", "表示順は整数で入力してください。")
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		s.renderTemplate(w, "material_detail", detail)
		return
	}

	input := materialPatchInput{
		LabelJA:       strings.TrimSpace(r.Form.Get("label_ja")),
		LabelEN:       strings.TrimSpace(r.Form.Get("label_en")),
		DescriptionJA: strings.TrimSpace(r.Form.Get("description_ja")),
		DescriptionEN: strings.TrimSpace(r.Form.Get("description_en")),
		PriceJPY:      price,
		SortOrder:     sortOrder,
		IsActive:      r.Form.Get("is_active") != "",
	}

	if err := s.updateMaterialWithContext(r.Context(), materialKey, input); err != nil {
		detail, ok := s.getMaterialDetail(materialKey, "", err.Error())
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		s.renderTemplate(w, "material_detail", detail)
		return
	}

	detail, ok := s.getMaterialDetail(materialKey, "材質マスタを更新しました。", "")
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("HX-Trigger", "material-updated")
	s.renderTemplate(w, "material_detail", detail)
}

func (s *server) updateOrderStatus(orderID, nextStatus, actorID string) error {
	return s.updateOrderStatusWithContext(context.Background(), orderID, nextStatus, actorID)
}

func (s *server) updateOrderStatusWithContext(ctx context.Context, orderID, nextStatus, actorID string) error {
	nextStatus = strings.TrimSpace(nextStatus)
	if nextStatus == "" {
		return errors.New("更新先のステータスを選択してください。")
	}

	s.mu.Lock()

	o, ok := s.orders[orderID]
	if !ok {
		s.mu.Unlock()
		return errors.New("注文が見つかりません。")
	}

	if o.Status == nextStatus {
		s.mu.Unlock()
		return errors.New("現在と同じステータスには更新できません。")
	}

	allowed := statusTransitions[o.Status]
	if !contains(allowed, nextStatus) {
		s.mu.Unlock()
		return fmt.Errorf("%s から %s には遷移できません。", lookupOrderStatusLabel(o.Status), lookupOrderStatusLabel(nextStatus))
	}

	now := time.Now().UTC()
	before := o.Status
	o.Status = nextStatus
	o.StatusUpdatedAt = now
	o.UpdatedAt = now
	applyDerivedStatuses(o)
	o.Events = append(o.Events, orderEvent{
		Type:         "status_changed",
		ActorType:    "admin",
		ActorID:      actorID,
		BeforeStatus: before,
		AfterStatus:  nextStatus,
		CreatedAt:    now,
	})
	newEvent := o.Events[len(o.Events)-1]
	updatedOrder := cloneOrder(o)
	s.mu.Unlock()

	if s.firestore != nil {
		if err := s.firestore.persistOrderMutation(ctx, updatedOrder, []orderEvent{newEvent}); err != nil {
			if reloadErr := s.refreshFromSource(context.Background()); reloadErr != nil {
				log.Printf("failed to rollback from firestore after status update error: %v", reloadErr)
			}
			return fmt.Errorf("firestore update failed: %w", err)
		}
	}

	return nil
}

func (s *server) updateShipping(orderID, carrier, trackingNo, transition, actorID string) error {
	return s.updateShippingWithContext(context.Background(), orderID, carrier, trackingNo, transition, actorID)
}

func (s *server) updateShippingWithContext(ctx context.Context, orderID, carrier, trackingNo, transition, actorID string) error {
	if carrier == "" {
		return errors.New("配送業者を入力してください。")
	}
	if trackingNo == "" {
		return errors.New("追跡番号を入力してください。")
	}

	s.mu.Lock()

	o, ok := s.orders[orderID]
	if !ok {
		s.mu.Unlock()
		return errors.New("注文が見つかりません。")
	}

	if transition != "" && transition != "none" {
		if o.Status == transition {
			s.mu.Unlock()
			return errors.New("現在と同じステータスは指定できません。")
		}

		allowed := statusTransitions[o.Status]
		if !contains(allowed, transition) {
			s.mu.Unlock()
			return fmt.Errorf("%s から %s には遷移できません。", lookupOrderStatusLabel(o.Status), lookupOrderStatusLabel(transition))
		}
	}

	now := time.Now().UTC()
	beforeStatus := o.Status
	newEvents := []orderEvent{}

	o.Carrier = carrier
	o.TrackingNo = trackingNo
	o.UpdatedAt = now
	o.Events = append(o.Events, orderEvent{
		Type:      "shipment_registered",
		ActorType: "admin",
		ActorID:   actorID,
		Note:      carrier + " / " + trackingNo,
		CreatedAt: now,
	})
	newEvents = append(newEvents, o.Events[len(o.Events)-1])

	if transition != "" && transition != "none" {
		o.Status = transition
		o.StatusUpdatedAt = now
		applyDerivedStatuses(o)
		o.Events = append(o.Events, orderEvent{
			Type:         "status_changed",
			ActorType:    "admin",
			ActorID:      actorID,
			BeforeStatus: beforeStatus,
			AfterStatus:  transition,
			CreatedAt:    now,
		})
		newEvents = append(newEvents, o.Events[len(o.Events)-1])
	}
	updatedOrder := cloneOrder(o)
	s.mu.Unlock()

	if s.firestore != nil {
		if err := s.firestore.persistOrderMutation(ctx, updatedOrder, newEvents); err != nil {
			if reloadErr := s.refreshFromSource(context.Background()); reloadErr != nil {
				log.Printf("failed to rollback from firestore after shipping update error: %v", reloadErr)
			}
			return fmt.Errorf("firestore update failed: %w", err)
		}
	}

	return nil
}

type materialPatchInput struct {
	LabelJA       string
	LabelEN       string
	DescriptionJA string
	DescriptionEN string
	PriceJPY      int
	SortOrder     int
	IsActive      bool
}

func (s *server) updateMaterial(key string, input materialPatchInput) error {
	return s.updateMaterialWithContext(context.Background(), key, input)
}

func (s *server) updateMaterialWithContext(ctx context.Context, key string, input materialPatchInput) error {
	if input.LabelJA == "" || input.LabelEN == "" {
		return errors.New("材質名（ja/en）は必須です。")
	}
	if input.DescriptionJA == "" || input.DescriptionEN == "" {
		return errors.New("説明文（ja/en）は必須です。")
	}
	if input.PriceJPY < 0 {
		return errors.New("価格は 0 以上で入力してください。")
	}
	if input.SortOrder < 0 {
		return errors.New("表示順は 0 以上で入力してください。")
	}

	s.mu.Lock()

	m, ok := s.materials[key]
	if !ok {
		s.mu.Unlock()
		return errors.New("材質が見つかりません。")
	}

	now := time.Now().UTC()
	m.LabelI18N["ja"] = input.LabelJA
	m.LabelI18N["en"] = input.LabelEN
	m.DescriptionI18N["ja"] = input.DescriptionJA
	m.DescriptionI18N["en"] = input.DescriptionEN
	m.PriceJPY = input.PriceJPY
	m.SortOrder = input.SortOrder
	m.IsActive = input.IsActive
	m.Version++
	m.UpdatedAt = now

	s.refreshMaterialIDsLocked()
	updatedMaterial := cloneMaterial(m)
	s.mu.Unlock()

	if s.firestore != nil {
		if err := s.firestore.persistMaterialMutation(ctx, updatedMaterial); err != nil {
			if reloadErr := s.refreshFromSource(context.Background()); reloadErr != nil {
				log.Printf("failed to rollback from firestore after material update error: %v", reloadErr)
			}
			return fmt.Errorf("firestore update failed: %w", err)
		}
	}
	return nil
}

func (s *server) filterOrders(filters orderFilter) []orderListItem {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]orderListItem, 0, len(s.orders))
	for _, id := range s.orderIDs {
		o := s.orders[id]
		if filters.Status != "" && o.Status != filters.Status {
			continue
		}
		if filters.Country != "" && !strings.EqualFold(o.CountryCode, filters.Country) {
			continue
		}
		if filters.Email != "" && !strings.Contains(strings.ToLower(o.ContactEmail), strings.ToLower(filters.Email)) {
			continue
		}

		items = append(items, orderListItem{
			ID:                o.ID,
			OrderNo:           o.OrderNo,
			CreatedAt:         o.CreatedAt,
			Status:            o.Status,
			PaymentStatus:     o.PaymentStatus,
			FulfillmentStatus: o.FulfillmentStatus,
			CountryCode:       o.CountryCode,
			CountryLabel:      s.countryLabel(o.CountryCode),
			ContactEmail:      o.ContactEmail,
			TotalJPY:          o.TotalJPY,
		})
	}

	return items
}

func (s *server) getOrderDetail(orderID, message, renderErr string) (orderDetailData, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	o, ok := s.orders[orderID]
	if !ok {
		return orderDetailData{}, false
	}

	events := make([]orderEvent, len(o.Events))
	copy(events, o.Events)
	sort.Slice(events, func(i, j int) bool {
		return events[i].CreatedAt.After(events[j].CreatedAt)
	})

	return orderDetailData{
		ID:                o.ID,
		OrderNo:           o.OrderNo,
		CreatedAt:         o.CreatedAt,
		UpdatedAt:         o.UpdatedAt,
		Status:            o.Status,
		StatusUpdatedAt:   o.StatusUpdatedAt,
		PaymentStatus:     o.PaymentStatus,
		FulfillmentStatus: o.FulfillmentStatus,
		TrackingNo:        o.TrackingNo,
		Carrier:           o.Carrier,
		CountryCode:       o.CountryCode,
		CountryLabel:      s.countryLabel(o.CountryCode),
		ContactEmail:      o.ContactEmail,
		Channel:           o.Channel,
		Locale:            o.Locale,
		SealLine1:         o.SealLine1,
		SealLine2:         o.SealLine2,
		MaterialLabelJA:   o.MaterialLabelJA,
		TotalJPY:          o.TotalJPY,
		NextStatuses:      nextStatuses(o.Status),
		ShippingTransitions: func() []statusOption {
			options := []statusOption{{Value: "none", Label: "ステータス変更なし"}}
			for _, next := range statusTransitions[o.Status] {
				if next == "manufacturing" || next == "shipped" || next == "delivered" {
					options = append(options, statusOption{Value: next, Label: lookupOrderStatusLabel(next)})
				}
			}
			return options
		}(),
		Events:  events,
		Message: message,
		Error:   renderErr,
	}, true
}

func (s *server) listMaterials() materialListData {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]materialListItem, 0, len(s.materialIDs))
	for _, key := range s.materialIDs {
		m := s.materials[key]
		items = append(items, materialListItem{
			Key:       m.Key,
			LabelJA:   m.LabelI18N["ja"],
			PriceJPY:  m.PriceJPY,
			IsActive:  m.IsActive,
			SortOrder: m.SortOrder,
			Version:   m.Version,
			UpdatedAt: m.UpdatedAt,
		})
	}

	return materialListData{Materials: items}
}

func (s *server) getMaterialDetail(key, message, renderErr string) (materialDetailData, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	m, ok := s.materials[key]
	if !ok {
		return materialDetailData{}, false
	}

	return materialDetailData{
		Key:           m.Key,
		LabelJA:       m.LabelI18N["ja"],
		LabelEN:       m.LabelI18N["en"],
		DescriptionJA: m.DescriptionI18N["ja"],
		DescriptionEN: m.DescriptionI18N["en"],
		PriceJPY:      m.PriceJPY,
		IsActive:      m.IsActive,
		SortOrder:     m.SortOrder,
		Version:       m.Version,
		UpdatedAt:     m.UpdatedAt,
		Message:       message,
		Error:         renderErr,
	}, true
}

func (s *server) refreshOrderIDs() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.refreshOrderIDsLocked()
}

func (s *server) refreshOrderIDsLocked() {
	ids := make([]string, 0, len(s.orders))
	for id := range s.orders {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool {
		return s.orders[ids[i]].CreatedAt.After(s.orders[ids[j]].CreatedAt)
	})
	s.orderIDs = ids
}

func (s *server) refreshMaterialIDs() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.refreshMaterialIDsLocked()
}

func (s *server) refreshMaterialIDsLocked() {
	keys := make([]string, 0, len(s.materials))
	for key := range s.materials {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		left := s.materials[keys[i]]
		right := s.materials[keys[j]]
		if left.SortOrder == right.SortOrder {
			return left.Key < right.Key
		}
		return left.SortOrder < right.SortOrder
	})
	s.materialIDs = keys
}

func (s *server) countryOptions() []countryOption {
	s.mu.RLock()
	defer s.mu.RUnlock()

	options := make([]countryOption, 0, len(s.countries))
	for code, label := range s.countries {
		options = append(options, countryOption{Code: code, Label: label})
	}
	sort.Slice(options, func(i, j int) bool {
		return options[i].Code < options[j].Code
	})
	return options
}

func (s *server) countryLabel(code string) string {
	if label, ok := s.countries[code]; ok {
		return label
	}
	return code
}

func statusOptions() []statusOption {
	keys := make([]string, 0, len(orderStatusLabels))
	for key := range orderStatusLabels {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	options := make([]statusOption, 0, len(keys))
	for _, key := range keys {
		options = append(options, statusOption{Value: key, Label: orderStatusLabels[key]})
	}
	return options
}

func nextStatuses(current string) []statusOption {
	next := statusTransitions[current]
	options := make([]statusOption, 0, len(next))
	for _, status := range next {
		options = append(options, statusOption{Value: status, Label: lookupOrderStatusLabel(status)})
	}
	return options
}

func parseOrderFilter(r *http.Request) orderFilter {
	return orderFilter{
		Status:  strings.TrimSpace(r.URL.Query().Get("status")),
		Country: strings.TrimSpace(r.URL.Query().Get("country")),
		Email:   strings.TrimSpace(r.URL.Query().Get("email")),
	}
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func applyDerivedStatuses(o *order) {
	switch o.Status {
	case "pending_payment":
		o.PaymentStatus = "unpaid"
		o.FulfillmentStatus = "pending"
	case "paid":
		o.PaymentStatus = "paid"
		o.FulfillmentStatus = "pending"
	case "manufacturing":
		o.PaymentStatus = "paid"
		o.FulfillmentStatus = "manufacturing"
	case "shipped":
		o.PaymentStatus = "paid"
		o.FulfillmentStatus = "shipped"
	case "delivered":
		o.PaymentStatus = "paid"
		o.FulfillmentStatus = "delivered"
	case "canceled":
		o.PaymentStatus = "failed"
		o.FulfillmentStatus = "pending"
	case "refunded":
		o.PaymentStatus = "refunded"
		if o.FulfillmentStatus == "" {
			o.FulfillmentStatus = "pending"
		}
	default:
		o.PaymentStatus = "processing"
		if o.FulfillmentStatus == "" {
			o.FulfillmentStatus = "pending"
		}
	}
}

func lookupOrderStatusLabel(status string) string {
	if label, ok := orderStatusLabels[status]; ok {
		return label
	}
	return status
}

func formatDateTime(t time.Time) string {
	if t.IsZero() {
		return "-"
	}
	return t.Local().Format("2006-01-02 15:04")
}

func formatYen(value int) string {
	if value == 0 {
		return "0"
	}

	n := strconv.Itoa(value)
	out := make([]byte, 0, len(n)+len(n)/3)
	for i := 0; i < len(n); i++ {
		if i > 0 && (len(n)-i)%3 == 0 {
			out = append(out, ',')
		}
		out = append(out, n[i])
	}
	return string(out)
}

func (s *server) renderTemplate(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := s.tmpl.ExecuteTemplate(w, name, data); err != nil {
		http.Error(w, fmt.Sprintf("failed to render %s: %v", name, err), http.StatusInternalServerError)
	}
}
