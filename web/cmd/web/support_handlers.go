package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/mail"
	"path/filepath"
	"strings"
	"time"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

const supportFormMaxMemory = int64(20 << 20) // 20 MiB

// SupportHandler renders the support page.
func SupportHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	renderSupportPage(w, r, lang, SupportFormState{})
}

// SupportSubmitHandler processes the contact form submission.
func SupportSubmitHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)

	if err := r.ParseMultipartForm(supportFormMaxMemory); err != nil {
		if !errors.Is(err, http.ErrNotMultipart) {
			http.Error(w, "form parse error", http.StatusBadRequest)
			return
		}
		if err := r.ParseForm(); err != nil {
			http.Error(w, "form parse error", http.StatusBadRequest)
			return
		}
	}

	input := SupportFormInput{
		Name:     strings.TrimSpace(r.FormValue("name")),
		Email:    strings.TrimSpace(r.FormValue("email")),
		Company:  strings.TrimSpace(r.FormValue("company")),
		Order:    strings.TrimSpace(r.FormValue("order")),
		Topic:    strings.TrimSpace(r.FormValue("topic")),
		Priority: strings.TrimSpace(r.FormValue("priority")),
		Message:  strings.TrimSpace(r.FormValue("message")),
	}

	var attachments []SupportAttachment
	var attachmentNames []string
	if r.MultipartForm != nil {
		if files := r.MultipartForm.File["attachments"]; len(files) > 0 {
			for _, fh := range files {
				if fh == nil || fh.Filename == "" {
					continue
				}
				name := filepath.Base(fh.Filename)
				size := fh.Size
				attachments = append(attachments, SupportAttachment{
					Filename: name,
					Size:     size,
				})
				attachmentNames = append(attachmentNames, name)
			}
		}
	}

	errorsMap := validateSupportInput(lang, input, attachments)

	state := SupportFormState{
		Values: map[string]string{
			"name":     input.Name,
			"email":    input.Email,
			"company":  input.Company,
			"order":    input.Order,
			"topic":    input.Topic,
			"priority": input.Priority,
			"message":  input.Message,
		},
		Errors:          errorsMap,
		AttachmentNames: attachmentNames,
	}

	if len(errorsMap) > 0 {
		state.Alert = &SupportAlert{
			Tone:  "error",
			Title: i18nOrDefault(lang, "support.form.error.title", "Please review the highlighted fields."),
			Body:  i18nOrDefault(lang, "support.form.error.body", "Provide the missing information so we can create your ticket."),
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		renderSupportPage(w, r, lang, state)
		return
	}

	ticket, err := submitSupportTicket(r.Context(), lang, input, attachments)
	if err != nil {
		state.Alert = &SupportAlert{
			Tone:  "error",
			Title: i18nOrDefault(lang, "support.form.error.submit_title", "We couldn't save your request."),
			Body:  fmt.Sprintf("%s %s", i18nOrDefault(lang, "support.form.error.submit_body", "Try again in a few moments."), err.Error()),
		}
		w.WriteHeader(http.StatusBadGateway)
		renderSupportPage(w, r, lang, state)
		return
	}

	state.Success = true
	state.Ticket = &ticket
	state.Alert = &SupportAlert{
		Tone:  "success",
		Title: fmt.Sprintf(i18nOrDefault(lang, "support.form.success.title", "Ticket %s received."), ticket.ID),
		Body: fmt.Sprintf(
			i18nOrDefault(lang, "support.form.success.body", "Expect a reply %s. We'll email %s once a specialist is assigned."),
			ticket.ResponseETA,
			input.Email,
		),
	}
	state.Values["message"] = ""
	// Keep topic/priority/name/email for convenience; attachments remain for acknowledgement.

	w.WriteHeader(http.StatusAccepted)
	renderSupportPage(w, r, lang, state)
}

func renderSupportPage(w http.ResponseWriter, r *http.Request, lang string, state SupportFormState) {
	view := buildSupportPageView(lang, state)

	vm := handlersPkg.PageData{
		Title: view.Header.Title,
		Lang:  lang,
	}
	vm.Path = r.URL.Path
	vm.Nav = nav.Build(vm.Path)
	crumbs := nav.Breadcrumbs(vm.Path)
	if len(crumbs) > 0 {
		crumbs[len(crumbs)-1].LabelKey = "support.header.title"
		crumbs[len(crumbs)-1].Label = ""
	}
	vm.Breadcrumbs = crumbs
	vm.Analytics = handlersPkg.LoadAnalyticsFromEnv()
	vm.Support = view

	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.Alternates = buildAlternates(r)
	vm.SEO.OG.URL = vm.SEO.Canonical

	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")
	vm.SEO.Title = fmt.Sprintf("%s | %s", view.Header.Title, brand)
	vm.SEO.Description = i18nOrDefault(lang, "support.seo.description", "Reach Hanko Field support for orders, billing, and technical help.")
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Type = "website"
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Twitter.Card = "summary_large_image"

	baseURL := siteBaseURL(r)
	for _, payload := range supportJSONLDPayloads(baseURL, lang, view) {
		if payload != "" {
			vm.SEO.JSONLD = append(vm.SEO.JSONLD, payload)
		}
	}

	renderPage(w, r, "support", vm)
}

type SupportFormInput struct {
	Name     string
	Email    string
	Company  string
	Order    string
	Topic    string
	Priority string
	Message  string
}

type SupportAttachment struct {
	Filename string
	Size     int64
}

func validateSupportInput(lang string, input SupportFormInput, attachments []SupportAttachment) map[string]string {
	errorsMap := make(map[string]string)
	if input.Name == "" {
		errorsMap["name"] = i18nOrDefault(lang, "support.form.error.name_required", "Tell us who to reach out to.")
	}
	if input.Email == "" {
		errorsMap["email"] = i18nOrDefault(lang, "support.form.error.email_required", "We need an email to send updates.")
	} else if _, err := mail.ParseAddress(input.Email); err != nil {
		errorsMap["email"] = i18nOrDefault(lang, "support.form.error.email_invalid", "Enter a valid email address.")
	}
	if input.Topic == "" {
		errorsMap["topic"] = i18nOrDefault(lang, "support.form.error.topic_required", "Select the topic that best matches your request.")
	} else if !isValidSupportTopic(input.Topic) {
		errorsMap["topic"] = i18nOrDefault(lang, "support.form.error.topic_supported", "Pick one of the listed topics.")
	}
	if input.Priority == "" {
		input.Priority = "normal"
	} else if !isValidSupportPriority(input.Priority) {
		errorsMap["priority"] = i18nOrDefault(lang, "support.form.error.priority_supported", "Choose a supported priority level.")
	}
	if input.Message == "" {
		errorsMap["message"] = i18nOrDefault(lang, "support.form.error.message_required", "Share details so we can assist quickly.")
	} else if len([]rune(input.Message)) < 16 {
		errorsMap["message"] = i18nOrDefault(lang, "support.form.error.message_length", "Include a bit more detail (at least 16 characters).")
	}

	if len(attachments) > supportMaxAttachments {
		errorsMap["attachments"] = fmt.Sprintf(
			i18nOrDefault(lang, "support.form.error.attachments_count", "Attach up to %d files."),
			supportMaxAttachments,
		)
	} else {
		for _, att := range attachments {
			if att.Size > int64(supportMaxAttachmentBytes) {
				errorsMap["attachments"] = fmt.Sprintf(
					i18nOrDefault(lang, "support.form.error.attachments_size", "Each file must be under %s."),
					humanReadableBytes(supportMaxAttachmentBytes),
				)
				break
			}
		}
	}

	return errorsMap
}

func isValidSupportTopic(topic string) bool {
	switch strings.ToLower(topic) {
	case "orders", "billing", "technical", "account":
		return true
	default:
		return false
	}
}

func isValidSupportPriority(priority string) bool {
	switch strings.ToLower(priority) {
	case "low", "normal", "high":
		return true
	default:
		return false
	}
}

func submitSupportTicket(ctx context.Context, lang string, input SupportFormInput, attachments []SupportAttachment) (SupportTicketInfo, error) {
	select {
	case <-ctx.Done():
		return SupportTicketInfo{}, ctx.Err()
	default:
	}

	// Simulate backend-side validation failure keywords.
	lowerMsg := strings.ToLower(input.Message)
	if strings.Contains(lowerMsg, "simulate:error") {
		return SupportTicketInfo{}, fmt.Errorf(i18nOrDefault(lang, "support.form.error.simulated", "Support endpoint temporarily unavailable."))
	}

	now := time.Now().UTC()
	ticketID := fmt.Sprintf("SUP-%s", now.Format("060102-150405"))
	responseETA := i18nOrDefault(lang, "support.response.eta", "within 2 business hours")
	followUp := fmt.Sprintf(
		i18nOrDefault(lang, "support.response.followup", "We'll email %s when a specialist picks up the ticket."),
		input.Email,
	)

	var attachmentList []string
	for _, att := range attachments {
		attachmentList = append(attachmentList, fmt.Sprintf("%s (%s)", att.Filename, humanReadableBytes(int(att.Size))))
	}
	if len(attachmentList) > 0 {
		followUp = fmt.Sprintf("%s %s", followUp, strings.Join(attachmentList, ", "))
	}

	return SupportTicketInfo{
		ID:          ticketID,
		Status:      "received",
		StatusLabel: i18nOrDefault(lang, "support.status.received", "Received"),
		ResponseETA: responseETA,
		FollowUp:    followUp,
		CreatedAt:   now,
	}, nil
}
