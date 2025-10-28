package main

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

// NotificationBellView powers the header notification bell and dropdown.
type NotificationBellView struct {
	Lang          string
	Open          bool
	Limit         int
	UnreadCount   int
	BadgeDisplay  string
	BadgeLabel    string
	EmptyMessage  string
	ViewAllHref   string
	ViewAllLabel  string
	MarkReadLabel string
	ViewLabel     string
	Items         []NotificationItemView
}

// NotificationPageView powers the full notifications archive page.
type NotificationPageView struct {
	Lang     string
	Heading  string
	Summary  string
	List     NotificationBellView
	LastSync time.Time
}

// NotificationItemView renders an individual notification entry.
type NotificationItemView struct {
	ID            string
	Title         string
	Body          string
	Href          string
	Read          bool
	CreatedAt     time.Time
	TimeLabel     string
	MarkReadLabel string
	ViewLabel     string
	UnreadLabel   string
}

type notificationSeed struct {
	ID            string
	TitleKey      string
	TitleFallback string
	BodyKey       string
	BodyFallback  string
	Href          string
	CreatedAgo    time.Duration
	DefaultRead   bool
}

func buildNotificationBellView(r *http.Request, lang string, open bool) NotificationBellView {
	if lang == "" {
		lang = mw.Lang(r)
	}
	limit := parseNotificationLimit(r)
	session := mw.GetSession(r)

	seeds := notificationSeeds()
	items := make([]NotificationItemView, 0, len(seeds))
	now := time.Now().UTC()
	for _, seed := range seeds {
		item := NotificationItemView{
			ID:        seed.ID,
			Title:     i18nOrDefault(lang, seed.TitleKey, seed.TitleFallback),
			Body:      i18nOrDefault(lang, seed.BodyKey, seed.BodyFallback),
			Href:      seed.Href,
			Read:      seed.DefaultRead,
			CreatedAt: now.Add(-seed.CreatedAgo),
		}
		if session != nil && session.IsNotificationRead(seed.ID) {
			item.Read = true
		}
		item.TimeLabel = relativeNotificationTime(lang, item.CreatedAt)
		item.MarkReadLabel = i18nOrDefault(lang, "notifications.markRead", "Mark as read")
		item.ViewLabel = i18nOrDefault(lang, "notifications.viewDetails", "View details")
		item.UnreadLabel = i18nOrDefault(lang, "notifications.unread", "Unread")
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})
	if limit > 0 && len(items) > limit {
		items = items[:limit]
	}

	unread := 0
	for _, item := range items {
		if !item.Read {
			unread++
		}
	}

	badgeDisplay := ""
	if unread > 0 {
		if unread > 9 {
			badgeDisplay = "9+"
		} else {
			badgeDisplay = fmt.Sprintf("%d", unread)
		}
	}
	emptyMessage := i18nOrDefault(lang, "notifications.empty", "You're all caught up.")
	viewAllLabel := i18nOrDefault(lang, "notifications.viewAll", "View all notifications")
	badgeLabel := ""
	if unread == 0 {
		badgeLabel = i18nOrDefault(lang, "notifications.badge.none", "No unread notifications")
	} else {
		pattern := i18nOrDefault(lang, "notifications.badge.count", "%d unread notifications")
		badgeLabel = fmt.Sprintf(pattern, unread)
	}

	return NotificationBellView{
		Lang:          lang,
		Open:          open,
		Limit:         limit,
		UnreadCount:   unread,
		BadgeDisplay:  badgeDisplay,
		BadgeLabel:    badgeLabel,
		EmptyMessage:  emptyMessage,
		ViewAllHref:   "/notifications",
		ViewAllLabel:  viewAllLabel,
		MarkReadLabel: i18nOrDefault(lang, "notifications.markRead", "Mark as read"),
		ViewLabel:     i18nOrDefault(lang, "notifications.viewDetails", "View details"),
		Items:         items,
	}
}

func buildNotificationPageView(r *http.Request, lang string) NotificationPageView {
	view := buildNotificationBellView(r, lang, false)
	view.Open = false
	heading := i18nOrDefault(lang, "notifications.page.title", "Notifications")
	summary := i18nOrDefault(lang, "notifications.page.subtitle", "Latest alerts about orders, designs, and account activity.")
	return NotificationPageView{
		Lang:     lang,
		Heading:  heading,
		Summary:  summary,
		List:     view,
		LastSync: time.Now().UTC(),
	}
}

func parseNotificationLimit(r *http.Request) int {
	q := r.URL.Query().Get("limit")
	if q == "" {
		return 10
	}
	n, err := strconv.Atoi(q)
	if err != nil {
		return 10
	}
	if n < 1 {
		return 1
	}
	if n > 20 {
		return 20
	}
	return n
}

func relativeNotificationTime(lang string, ts time.Time) string {
	now := time.Now()
	if ts.After(now) {
		ts = now
	}
	diff := now.Sub(ts)
	if diff < time.Minute {
		return i18nOrDefault(lang, "notifications.time.justNow", "Just now")
	}
	if diff < time.Hour {
		minutes := int(diff.Minutes())
		if minutes < 1 {
			minutes = 1
		}
		pattern := i18nOrDefault(lang, "notifications.time.minutes", "%d minutes ago")
		return fmt.Sprintf(pattern, minutes)
	}
	if diff < 24*time.Hour {
		hours := int(diff.Hours())
		if hours < 1 {
			hours = 1
		}
		pattern := i18nOrDefault(lang, "notifications.time.hours", "%d hours ago")
		return fmt.Sprintf(pattern, hours)
	}
	days := int(diff.Hours() / 24)
	if days < 1 {
		days = 1
	}
	pattern := i18nOrDefault(lang, "notifications.time.days", "%d days ago")
	return fmt.Sprintf(pattern, days)
}

func notificationSeeds() []notificationSeed {
	return []notificationSeed{
		{
			ID:            "order-HD-1042-ready",
			TitleKey:      "notifications.sample.orderReady.title",
			TitleFallback: "Order HD-1042 is ready for pickup",
			BodyKey:       "notifications.sample.orderReady.body",
			BodyFallback:  "Your carved seal finished early. Confirm pickup or choose courier delivery.",
			Href:          "/account/orders/HD-1042",
			CreatedAgo:    75 * time.Minute,
			DefaultRead:   false,
		},
		{
			ID:            "design-LP-22-approved",
			TitleKey:      "notifications.sample.designApproved.title",
			TitleFallback: "Design variant LP-22 approved",
			BodyKey:       "notifications.sample.designApproved.body",
			BodyFallback:  "The compliance team approved your legal-use variant. It's ready for stamping.",
			Href:          "/account/library?design=LP-22",
			CreatedAgo:    6 * time.Hour,
			DefaultRead:   false,
		},
		{
			ID:            "shipping-slot-availability",
			TitleKey:      "notifications.sample.shippingSlot.title",
			TitleFallback: "Weekend shipping slots released",
			BodyKey:       "notifications.sample.shippingSlot.body",
			BodyFallback:  "Reserve a Saturday delivery window for metropolitan Tokyo orders.",
			Href:          "/checkout/shipping",
			CreatedAgo:    20 * time.Hour,
			DefaultRead:   true,
		},
		{
			ID:            "guide-workshop-reminder",
			TitleKey:      "notifications.sample.workshopReminder.title",
			TitleFallback: "Reminder: Workshop streams tomorrow",
			BodyKey:       "notifications.sample.workshopReminder.body",
			BodyFallback:  "Join the live carving workshop. Seats are limited; reserve your spot.",
			Href:          "/guides",
			CreatedAgo:    48 * time.Hour,
			DefaultRead:   true,
		},
	}
}

func notificationExists(id string) bool {
	if id == "" {
		return false
	}
	for _, seed := range notificationSeeds() {
		if seed.ID == id {
			return true
		}
	}
	return false
}
