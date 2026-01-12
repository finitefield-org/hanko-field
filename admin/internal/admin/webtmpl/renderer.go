package webtmpl

import (
	"bytes"
	"embed"
	"html/template"
	"net/http"
	"reflect"
	"strings"
)

//go:embed templates/**/*.html
var templateFS embed.FS

// Renderer holds parsed html/template sets for the admin UI.
type Renderer struct {
	templates *template.Template
}

// New loads and parses embedded templates.
func New() (*Renderer, error) {
	tmpl, err := template.New("admin").Funcs(templateFuncs).ParseFS(
		templateFS,
		"templates/layouts/*.html",
		"templates/auth/*.html",
		"templates/partials/*.html",
		"templates/dashboard/*.html",
		"templates/components/*.html",
		"templates/pages/*.html",
		"templates/notifications/*.html",
		"templates/auditlogs/*.html",
		"templates/orders/*.html",
		"templates/shipments/*.html",
		"templates/reviews/*.html",
		"templates/customers/*.html",
		"templates/finance/*.html",
		"templates/production/*.html",
		"templates/productionqueues/*.html",
		"templates/promotions/*.html",
		"templates/guides/*.html",
		"templates/search/*.html",
		"templates/payments/*.html",
		"templates/system/*.html",
		"templates/catalog/*.html",
		"templates/profile/*.html",
		"templates/org/*.html",
		"templates/promotionusage/*.html",
	)
	if err != nil {
		return nil, err
	}
	return &Renderer{templates: tmpl}, nil
}

// MustNew creates a renderer or panics on parse error.
func MustNew() *Renderer {
	renderer, err := New()
	if err != nil {
		panic(err)
	}
	return renderer
}

// Render writes the named template to the response writer.
func (r *Renderer) Render(w http.ResponseWriter, name string, data any) error {
	hydrated, err := r.injectContentHTML(data)
	if err != nil {
		return err
	}
	return r.templates.ExecuteTemplate(w, name, hydrated)
}

func (r *Renderer) injectContentHTML(data any) (any, error) {
	if data == nil {
		return data, nil
	}

	value := reflect.ValueOf(data)
	switch value.Kind() {
	case reflect.Pointer:
		if value.IsNil() || value.Elem().Kind() != reflect.Struct {
			return data, nil
		}
		clone := reflect.New(value.Elem().Type())
		clone.Elem().Set(value.Elem())
		if err := r.applyContentTemplate(clone.Elem()); err != nil {
			return data, err
		}
		return clone.Interface(), nil
	case reflect.Struct:
		clone := reflect.New(value.Type()).Elem()
		clone.Set(value)
		if err := r.applyContentTemplate(clone); err != nil {
			return data, err
		}
		return clone.Interface(), nil
	default:
		return data, nil
	}
}

func (r *Renderer) applyContentTemplate(value reflect.Value) error {
	contentTemplateField := value.FieldByName("ContentTemplate")
	if !contentTemplateField.IsValid() || contentTemplateField.Kind() != reflect.String {
		return nil
	}

	contentTemplate := strings.TrimSpace(contentTemplateField.String())
	if contentTemplate == "" {
		return nil
	}

	contentHTMLField := value.FieldByName("ContentHTML")
	if !contentHTMLField.IsValid() || !contentHTMLField.CanSet() || contentHTMLField.Kind() != reflect.String {
		return nil
	}
	if contentHTMLField.String() != "" {
		return nil
	}

	var buf bytes.Buffer
	if err := r.templates.ExecuteTemplate(&buf, contentTemplate, value.Interface()); err != nil {
		return err
	}
	contentHTMLField.SetString(buf.String())
	return nil
}
