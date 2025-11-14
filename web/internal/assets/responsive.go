package assets

import (
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
)

var (
	defaultWidths = []int{320, 480, 640, 768, 960, 1280, 1536, 1920}
	sizePresets   = map[string]string{
		"default":       "(min-width: 1440px) 960px, (min-width: 1024px) 75vw, 92vw",
		"hero":          "(min-width: 1280px) 960px, 100vw",
		"card":          "(min-width: 1280px) 33vw, (min-width: 640px) 50vw, 92vw",
		"grid-card":     "(min-width: 1536px) 25vw, (min-width: 1024px) 33vw, (min-width: 640px) 50vw, 92vw",
		"gallery-main":  "(min-width: 1280px) 60vw, (min-width: 768px) 70vw, 100vw",
		"gallery-thumb": "(min-width: 1280px) 160px, (min-width: 768px) 120px, 96px",
		"avatar":        "96px",
		"thumb":         "160px",
		"table-thumb":   "(min-width: 1024px) 240px, (min-width: 640px) 200px, 160px",
		"article":       "(min-width: 1280px) 720px, (min-width: 768px) 70vw, 92vw",
	}

	resizeHostOnce sync.Once
	resizeHosts    map[string]struct{}
)

// ResponsiveSrcset produces a srcset string. Width query parameters are only added
// when the source host is explicitly whitelisted via HANKO_WEB_IMAGE_RESIZE_HOSTS.
func ResponsiveSrcset(src string, widths ...int) string {
	src = strings.TrimSpace(src)
	if src == "" {
		return ""
	}
	if strings.HasPrefix(src, "data:") {
		return src
	}
	ws := normalizeWidths(widths)
	if len(ws) == 0 {
		ws = defaultWidths
	}

	u, err := url.Parse(src)
	if err != nil || u == nil {
		return src
	}
	if u.Host == "" {
		return src
	}

	if !widthParamAllowed(strings.ToLower(u.Host)) {
		return src
	}

	var parts []string
	for _, w := range ws {
		if w <= 0 {
			continue
		}
		parts = append(parts, widthDescriptor(cloneURL(u), w))
	}
	if len(parts) == 0 {
		return src
	}
	return strings.Join(parts, ", ")
}

// ResponsiveSizes returns a sizes attribute string from predefined presets.
func ResponsiveSizes(preset string) string {
	preset = strings.TrimSpace(strings.ToLower(preset))
	if preset == "" {
		preset = "default"
	}
	if sizes, ok := sizePresets[preset]; ok {
		return sizes
	}
	return sizePresets["default"]
}

func normalizeWidths(widths []int) []int {
	if len(widths) == 0 {
		return nil
	}
	set := map[int]struct{}{}
	var out []int
	for _, w := range widths {
		if w <= 0 {
			continue
		}
		if _, exists := set[w]; exists {
			continue
		}
		set[w] = struct{}{}
		out = append(out, w)
	}
	sort.Ints(out)
	return out
}

func widthDescriptor(u *url.URL, width int) string {
	q := u.Query()
	q.Set("width", strconv.Itoa(width))
	u.RawQuery = q.Encode()
	return u.String() + " " + strconv.Itoa(width) + "w"
}

func cloneURL(u *url.URL) *url.URL {
	clone := *u
	return &clone
}

func widthParamAllowed(host string) bool {
	resizeHostOnce.Do(func() {
		resizeHosts = map[string]struct{}{}
		for _, entry := range strings.Split(os.Getenv("HANKO_WEB_IMAGE_RESIZE_HOSTS"), ",") {
			host := strings.TrimSpace(strings.ToLower(entry))
			if host == "" {
				continue
			}
			resizeHosts[host] = struct{}{}
		}
	})
	_, ok := resizeHosts[host]
	return ok
}
