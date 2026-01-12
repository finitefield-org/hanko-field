package components

// ButtonOptions configures shared button styling.
type ButtonOptions struct {
	Variant   string
	Size      string
	Type      string
	Href      string
	FullWidth bool
	Disabled  bool
	Loading   bool
	Attrs     map[string]string
}

// BulkToolbarAction represents a bulk action entry.
type BulkToolbarAction struct {
	Label       string
	Description string
	Options     ButtonOptions
}

// BulkToolbarProps configures the bulk action toolbar.
type BulkToolbarProps struct {
	SelectedCount   int
	TotalCount      int
	Message         string
	ClearAction     *BulkToolbarAction
	Actions         []BulkToolbarAction
	Attrs           map[string]string
	RenderWhenEmpty bool
}

// UnderlineTab represents a single tab in an underline tab set.
type UnderlineTab struct {
	ID         string
	Label      string
	Href       string
	Active     bool
	Attributes map[string]string
}

// UnderlineTabsProps configures an underline tab group.
type UnderlineTabsProps struct {
	Tabs      []UnderlineTab
	HxTarget  string
	HxSwap    string
	HxPushURL bool
}

// PageInfo captures pagination state.
type PageInfo struct {
	PageSize   int
	Current    int
	Count      int
	TotalItems *int
	Next       *int
	Prev       *int
}

// PaginationProps configures pagination controls.
type PaginationProps struct {
	Info          PageInfo
	BasePath      string
	RawQuery      string
	FragmentPath  string
	FragmentQuery string
	Param         string
	SizeParam     string
	HxTarget      string
	HxSwap        string
	HxPushURL     bool
	Attrs         map[string]string
	Label         string
}
