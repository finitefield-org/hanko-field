package org

// StaffRoleOption describes a selectable role within modal forms.
type StaffRoleOption struct {
	Key         string
	Label       string
	Description string
	Checked     bool
}

// StaffInviteModalPayload contains data for the invite modal.
type StaffInviteModalPayload struct {
	Action      string
	CSRFToken   string
	Values      StaffInviteFormValues
	RoleOptions []StaffRoleOption
	Error       string
}

// StaffInviteFormValues captures posted form values to preserve state on validation errors.
type StaffInviteFormValues struct {
	Email     string
	Name      string
	Roles     []string
	SendEmail bool
	Note      string
}

// StaffEditModalPayload contains data for the role edit modal.
type StaffEditModalPayload struct {
	Action      string
	CSRFToken   string
	MemberName  string
	MemberEmail string
	RoleOptions []StaffRoleOption
	Note        string
	Error       string
}

// StaffRevokeModalPayload contains data for the revocation modal.
type StaffRevokeModalPayload struct {
	Action         string
	CSRFToken      string
	MemberName     string
	MemberEmail    string
	Reason         string
	Note           string
	RevokeSessions bool
	NotifyUser     bool
	Error          string
}
