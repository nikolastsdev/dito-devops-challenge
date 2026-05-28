variable "billing_account_id" {
  description = "Billing Account ID (012345-678901-ABCDEF)"
  type        = string
}

variable "billing_account_scope" {
  description = "true = orçamento cobre TODA a billing account (recomendado com 2 projects)"
  type        = bool
  default     = true
}

variable "budget_amount_brl" {
  type    = number
  default = 1700
}

variable "budget_alert_emails" {
  type = list(string)
}

variable "project_id" {
  description = "Project ID onde criar notification channels (use staging)"
  type        = string
  default     = ""
}

variable "environment" { type = string }
variable "project_name" { type = string }

resource "google_billing_budget" "main" {
  provider        = google-beta
  billing_account = var.billing_account_id
  display_name    = var.billing_account_scope ? "${var.project_name}-budget-total-trial" : "${var.project_name}-budget-${var.environment}"

  dynamic "budget_filter" {
    for_each = var.billing_account_scope ? [] : [1]
    content {
      projects = ["projects/${var.project_id}"]
    }
  }

  amount {
    specified_amount {
      currency_code = "BRL"
      units         = tostring(var.budget_amount_brl)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.25, 0.5, 0.75, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "all_updates_rule" {
    for_each = length(var.budget_alert_emails) > 0 ? [1] : []
    content {
      monitoring_notification_channels = [
        for email in var.budget_alert_emails :
        google_monitoring_notification_channel.email[email].name
      ]
      disable_default_iam_recipients = false
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.budget_alert_emails)

  project      = var.project_id != "" ? var.project_id : null
  display_name = "Budget Alert — ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }
}

output "budget_name" {
  value = google_billing_budget.main.display_name
}
