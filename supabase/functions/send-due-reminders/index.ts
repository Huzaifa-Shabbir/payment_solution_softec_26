import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type ReminderType = "gentle" | "strong" | "escalation";
type MessageTone = "soft" | "professional" | "strict";

interface AccountRow {
  id: string;
  name: string;
  email: string;
  amount: number;
  due_date: string;
}

interface CustomerRow {
  id: string;
  name: string;
  email: string;
  amount: number;
  due_Date?: string;
  due_date?: string;
  status?: string;
  is_paid?: boolean;
}

interface EmailMessage {
  subject: string;
  body: string;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = Deno.env.get("REMINDER_FROM_EMAIL")!;

Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}));
    const dryRun = body?.dryRun === true;
    const messageTone = (body?.tone ?? "professional") as MessageTone;

    const today = dateOnly(new Date());

    const customerId =
      typeof body?.customerId === "string" ? body.customerId : null;

    const mode = body?.mode ?? "scheduled"; // "instant" or "scheduled"

    const accounts = await fetchCustomers(today, customerId);

    let sent = 0;
    let skipped = 0;
    let failed = 0;

    for (const account of accounts) {
      const delayDays = diffDays(today, account.due_date);

      let reminderType: ReminderType | null = null;

      // INSTANT MODE (called from Flutter after insert)
      if (mode === "instant") {
        // send immediately if due or past due (0 = due today)
        if (delayDays >= 0) {
          reminderType = "gentle"; // first message
        } else {
          skipped++;
          continue;
        }
      }

      // SCHEDULED MODE (cron)
      else {
        // skip if not due yet
        if (delayDays < 0) {
          skipped++;
          continue;
        }

        // send every 2 days only
        if (delayDays % 2 !== 0) {
          skipped++;
          continue;
        }

        // escalation rules
        if (delayDays >= 0 && delayDays <= 3) reminderType = "gentle";
        else if (delayDays <= 10) reminderType = "strong";
        else reminderType = "escalation";
      }

      // Check if reminder already sent today
      const logRes = await fetch(
        `${SUPABASE_URL}/rest/v1/reminder_logs?account_id=eq.${account.id}&reminder_type=eq.${reminderType}&reminder_day=eq.${today}`,
        {
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
          },
        }
      );

      const logs = await logRes.json();
      if (Array.isArray(logs) && logs.length > 0) {
        skipped++;
        continue;
      }

      if (dryRun) {
        console.log(
          `[DRY RUN] Would send ${reminderType} reminder (${messageTone} tone) to ${account.email}`
        );
        skipped++;
        continue;
      }

      // Generate message using same logic as Flutter app
      const emailMsg = generateEmailMessage(
        account,
        reminderType,
        messageTone
      );

      try {
        // Send via Resend
        const resendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: FROM_EMAIL,
            to: [account.email],
            subject: emailMsg.subject,
            text: emailMsg.body,
          }),
        });

        const resendPayload = await resendRes.json();
        const messageId = resendPayload?.id ?? "";

        // Log success
        await fetch(`${SUPABASE_URL}/rest/v1/reminder_logs`, {
          method: "POST",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            account_id: account.id,
            reminder_type: reminderType,
            reminder_day: today,
            sent_success: true,
            provider_message_id: messageId,
          }),
        });

        // Update customer's follow-up dates
        try {
          const nextFollowUp = new Date();
          nextFollowUp.setDate(nextFollowUp.getDate() + 2);

          await fetch(`${SUPABASE_URL}/rest/v1/customers?id=eq.${account.id}`, {
            method: "PATCH",
            headers: {
              apikey: SERVICE_KEY,
              Authorization: `Bearer ${SERVICE_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              last_follow_up: today,
              next_follow_up: nextFollowUp.toISOString().slice(0, 10),
            }),
          });
        } catch (e) {
          console.error("Failed to update follow-up dates:", e instanceof Error ? e.message : `${e}`);
        }

        sent++;
        console.log(
          `Sent ${reminderType} reminder to ${account.email} (id=${messageId})`
        );
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : `${error}`;
        console.error(
          `Failed to send to ${account.email}:`,
          errorMsg
        );

        // Log failure
        await fetch(`${SUPABASE_URL}/rest/v1/reminder_logs`, {
          method: "POST",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            account_id: account.id,
            reminder_type: reminderType,
            reminder_day: today,
            sent_success: false,
            error_message: errorMsg,
          }),
        });

        failed++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        total: accounts.length,
        sent,
        skipped,
        failed,
        dryRun,
        tone: messageTone,
        runDate: today,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : `${error}`;
    console.error("Function error:", message);
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function diffDays(todayStr: string, dueDateStr: string): number {
  const today = new Date(`${todayStr}T00:00:00Z`).getTime();
  const dueDate = new Date(`${dueDateStr}T00:00:00Z`).getTime();
  return Math.floor((today - dueDate) / (1000 * 60 * 60 * 24));
}

function formatDate(dateStr: string): string {
  const date = new Date(`${dateStr}T00:00:00Z`);
  return date.toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function generateEmailMessage(
  account: AccountRow,
  reminderType: ReminderType,
  tone: MessageTone
): EmailMessage {
  const amount = `$${Number(account.amount).toFixed(2)}`;
  const dueDate = formatDate(account.due_date);
  const name = account.name;

  // Soft tone messages (gentle/friendly)
  if (tone === "soft") {
    if (reminderType === "gentle") {
      return {
        subject: "Friendly Payment Reminder",
        body:
          `Dear ${name},\n\n` +
          `I hope you are doing well. This is a gentle reminder that the payment of ${amount} ` +
          `was due on ${dueDate}.\n\n` +
          `Kindly share an update at your convenience.\n\n` +
          "Best regards,",
      };
    }
    if (reminderType === "strong") {
      return {
        subject: "Payment Follow-Up Required",
        body:
          `Dear ${name},\n\n` +
          `I would appreciate your attention regarding the payment of ${amount}, ` +
          `due on ${dueDate}.\n\n` +
          `Please kindly provide an update on the payment status.\n\n` +
          "Best regards,",
      };
    }
    return {
      subject: "Urgent: Payment Overdue",
      body:
        `Dear ${name},\n\n` +
        `I hope this message finds you well. The payment of ${amount}, due on ${dueDate}, ` +
        `is now significantly overdue.\n\n` +
        `Please treat this matter with priority and respond as soon as possible.\n\n` +
        "Best regards,",
    };
  }

  // Professional tone messages (default)
  if (tone === "professional") {
    if (reminderType === "gentle") {
      return {
        subject: "Friendly Payment Reminder",
        body:
          `Dear ${name},\n\n` +
          `This is a gentle reminder that the payment of ${amount} was due on ${dueDate}.\n\n` +
          `Please share an update when convenient.\n\n` +
          "Best regards,",
      };
    }
    if (reminderType === "strong") {
      return {
        subject: "Payment Follow-Up",
        body:
          `Dear ${name},\n\n` +
          `This is a formal reminder regarding the outstanding amount of ${amount}, ` +
          `due on ${dueDate}.\n\n` +
          `Please confirm your expected payment date.\n\n` +
          "Regards,",
      };
    }
    return {
      subject: "Urgent: Outstanding Payment",
      body:
        `Dear ${name},\n\n` +
        `Your payment of ${amount}, due on ${dueDate}, remains unpaid.\n\n` +
        `Please arrange immediate payment and confirmation.\n\n` +
        "Sincerely,",
    };
  }

  // Strict tone messages
  if (reminderType === "gentle") {
    return {
      subject: "Payment Due",
      body:
        `${name},\n\n` +
        `Your payment of ${amount} was due on ${dueDate}.\n` +
        `Please process immediately.\n\n` +
        "Regards,",
    };
  }
  if (reminderType === "strong") {
    return {
      subject: "OVERDUE: Immediate Payment Required",
      body:
        `${name},\n\n` +
        `Your payment of ${amount}, due on ${dueDate}, is now overdue.\n` +
        `Immediate action is required. Confirm payment today.\n\n` +
        "Regards,",
    };
  }
  return {
    subject: "FINAL NOTICE: Overdue Payment",
    body:
      `${name},\n\n` +
      `Your payment of ${amount}, due on ${dueDate}, is severely overdue.\n` +
      `Immediate payment and confirmation are non-negotiable. Act now.\n\n` +
      "Regards,",
  };
}

async function fetchCustomers(
  today: string,
  customerId: string | null
): Promise<AccountRow[]> {
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
  };

  let query = "";

  if (customerId) {
    query = `${SUPABASE_URL}/rest/v1/customers?id=eq.${customerId}&select=id,name,email,amount,due_date,status`;
  } else {
    query = `${SUPABASE_URL}/rest/v1/customers?select=id,name,email,amount,due_date,status`;
  }

  const res = await fetch(query, { headers });

  if (!res.ok) {
    throw new Error("Failed to fetch customers");
  }

  const rows = (await res.json()) as CustomerRow[];

  return rows
    .filter((row) => {
      const status = `${row.status ?? ""}`.toLowerCase();
      return status !== "paid" && row.is_paid !== true;
    })
    .map((row) => ({
      id: row.id,
      name: row.name,
      email: row.email,
      amount: Number(row.amount ?? 0),
      due_date: row.due_Date ?? row.due_date ?? today,
    }));
}
