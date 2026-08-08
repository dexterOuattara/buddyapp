//! Hand-rolled iCal (RFC 5545) parser, scoped to what we actually need:
//! extract `VEVENT` blocks with optional `RRULE` recurrence, expand
//! each occurrence into a separate `AgendaItemDraft` within a 90-day
//! window from today.
//!
//! Deliberately *not* a full RFC 5545 implementation. We handle:
//! - VEVENT blocks (the only thing we care about)
//! - SUMMARY (becomes the title)
//! - DTSTART / DTEND in UTC or local format
//! - LOCATION (becomes notes)
//! - RRULE with FREQ=DAILY|WEEKLY (with BYDAY and INTERVAL)
//! - EXDATE exclusions
//!
//! We do NOT handle RDATE additions, recurrence overrides (RECURRENCE-ID),
//! time zones other than UTC, or VTODO / VJOURNAL.

use std::collections::HashSet;

use chrono::{DateTime, Datelike, Duration, NaiveDate, NaiveDateTime, TimeZone, Utc, Weekday};

use crate::providers::AgendaItemDraft;

/// How far into the future we expand recurring events. iCal entries
/// with `RRULE:FREQ=DAILY` would otherwise expand to infinity.
const EXPANSION_WINDOW_DAYS: i64 = 90;

/// Maximum number of drafts returned from one parse. Beyond this the
/// UI is unusable and the user's data is suspicious.
const MAX_DRAFTS: usize = 200;

pub fn parse_ical(text: &str) -> anyhow::Result<Vec<AgendaItemDraft>> {
    let events = extract_events(text)?;
    let now = Utc::now();
    let horizon = now + Duration::days(EXPANSION_WINDOW_DAYS);

    let mut drafts = Vec::new();
    for ev in events {
        for (start, end) in ev.expand(now, horizon) {
            if let Some(d) = ev.occurrence_to_draft(start, end) {
                drafts.push(d);
            }
            if drafts.len() >= MAX_DRAFTS {
                tracing::warn!("iCal: hit MAX_DRAFTS={}, truncating", MAX_DRAFTS);
                return Ok(drafts);
            }
        }
    }
    Ok(drafts)
}

// ---------- iCal structure ----------

#[derive(Debug)]
struct VEvent {
    summary: String,
    location: Option<String>,
    dtstart: NaiveDateTime,
    dtstart_tz_is_utc: bool,
    dtend: Option<NaiveDateTime>,
    rrule: Option<RRule>,
    exdates: HashSet<NaiveDateTime>,
}

#[derive(Debug, Clone)]
struct RRule {
    freq: Freq,
    interval: u32,
    by_day: Vec<Weekday>,
    until: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Freq {
    Daily,
    Weekly,
}

impl VEvent {
    fn empty() -> Self {
        Self {
            summary: String::new(),
            location: None,
            dtstart: NaiveDate::from_ymd_opt(1970, 1, 1)
                .unwrap()
                .and_hms_opt(0, 0, 0)
                .unwrap(),
            dtstart_tz_is_utc: true,
            dtend: None,
            rrule: None,
            exdates: HashSet::new(),
        }
    }

    fn to_utc(&self, dt: NaiveDateTime) -> DateTime<Utc> {
        if self.dtstart_tz_is_utc {
            Utc.from_utc_datetime(&dt)
        } else {
            // Treat local-as-UTC: the user's local clock is usually close
            // enough for a study agenda. Real timezones would require a
            // tzdata lookup at runtime.
            Utc.from_utc_datetime(&dt)
        }
    }

    fn occurrence_to_draft(
        &self,
        start: DateTime<Utc>,
        end: Option<DateTime<Utc>>,
    ) -> Option<AgendaItemDraft> {
        let title = self.summary.trim();
        if title.is_empty() {
            return None;
        }
        Some(AgendaItemDraft {
            title: title.to_string(),
            starts_at: Some(start.to_rfc3339()),
            ends_at: end.map(|d| d.to_rfc3339()),
            notes: self
                .location
                .as_ref()
                .map(|l| l.trim().to_string())
                .filter(|l| !l.is_empty()),
        })
    }

    fn expand(
        &self,
        from: DateTime<Utc>,
        to: DateTime<Utc>,
    ) -> Vec<(DateTime<Utc>, Option<DateTime<Utc>>)> {
        let dtstart_utc = self.to_utc(self.dtstart);
        let dtend_utc = self.dtend.map(|d| self.to_utc(d));

        let mut out = Vec::new();
        match &self.rrule {
            None => {
                if dtstart_utc >= from && dtstart_utc <= to {
                    out.push((dtstart_utc, dtend_utc));
                }
            }
            Some(rule) => {
                let mut current = dtstart_utc;
                let mut iterations = 0u32;
                const MAX_ITERATIONS: u32 = 1000;
                while current <= to && iterations < MAX_ITERATIONS {
                    iterations += 1;
                    if current > from && !self.exdates.contains(&current.naive_utc()) {
                        let end = dtend_utc.map(|e| {
                            let duration = e - dtstart_utc;
                            current + duration
                        });
                        out.push((current, end));
                    }
                    current = match rule.freq {
                        Freq::Daily => current + Duration::days(rule.interval as i64),
                        Freq::Weekly => {
                            if rule.by_day.is_empty() {
                                current + Duration::weeks(rule.interval as i64)
                            } else {
                                advance_weekly(current, &rule.by_day, rule.interval)
                            }
                        }
                    };
                    if let Some(u) = rule.until {
                        if current > u {
                            break;
                        }
                    }
                }
            }
        }
        out
    }
}

fn advance_weekly(
    current: DateTime<Utc>,
    by_day: &[Weekday],
    interval: u32,
) -> DateTime<Utc> {
    let current_wd = current.weekday();
    let mut candidate = current;
    for _ in 0..7 {
        candidate = candidate + Duration::days(1);
        if by_day.contains(&candidate.weekday()) {
            break;
        }
    }
    if (candidate.weekday() as u32) < (current_wd as u32) {
        candidate = candidate + Duration::weeks((interval - 1) as i64);
    }
    candidate
}

// ---------- parsing ----------

fn extract_events(text: &str) -> anyhow::Result<Vec<VEvent>> {
    let unfolded = unfold_lines(text);

    let mut events = Vec::new();
    let mut current: Option<VEvent> = None;
    let mut in_event = false;

    for line in unfolded.lines() {
        if line.is_empty() {
            continue;
        }
        if line.eq_ignore_ascii_case("BEGIN:VEVENT") {
            current = Some(VEvent::empty());
            in_event = true;
            continue;
        }
        if line.eq_ignore_ascii_case("END:VEVENT") {
            if let Some(ev) = current.take() {
                if !ev.summary.is_empty() {
                    events.push(ev);
                }
            }
            in_event = false;
            continue;
        }
        if !in_event {
            continue;
        }
        if let Some(ev) = current.as_mut() {
            apply_line(ev, line);
        }
    }
    Ok(events)
}

fn unfold_lines(text: &str) -> String {
    // RFC 5545 line unfolding:
    //   - line endings are CRLF, LF, or CR
    //   - a line that starts with a SPACE or HTAB is a continuation of
    //     the previous line; the leading whitespace is the fold separator
    //     and is dropped, then the rest of the line is appended with no
    //     separator
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    // `pending_newline` is true when we just consumed a line break and
    // haven't yet decided whether the next line is a continuation.
    let mut pending_newline = false;
    while let Some(ch) = chars.next() {
        match ch {
            '\r' => {
                if chars.peek() == Some(&'\n') {
                    chars.next();
                }
                pending_newline = true;
            }
            '\n' => {
                pending_newline = true;
            }
            ' ' | '\t' if pending_newline => {
                // Continuation: drop the single fold separator, discard
                // the pending newline, then continue normally.
                pending_newline = false;
            }
            _ => {
                if pending_newline {
                    out.push('\n');
                    pending_newline = false;
                }
                out.push(ch);
            }
        }
    }
    if pending_newline {
        out.push('\n');
    }
    out
}

fn apply_line(ev: &mut VEvent, line: &str) {
    let (name, value) = match line.split_once(':') {
        Some((n, v)) => (n.to_ascii_uppercase(), v),
        None => return,
    };
    let (base_name, params) = split_name_and_params(name);
    match base_name.as_str() {
        "SUMMARY" => ev.summary = unescape_text(value),
        "LOCATION" => ev.location = Some(unescape_text(value)),
        "DTSTART" => {
            if let Some((dt, is_utc)) = parse_dt(value, &params) {
                ev.dtstart = dt;
                ev.dtstart_tz_is_utc = is_utc;
            }
        }
        "DTEND" => {
            if let Some((dt, _)) = parse_dt(value, &params) {
                ev.dtend = Some(dt);
            }
        }
        "RRULE" => ev.rrule = parse_rrule(value),
        "EXDATE" => {
            if let Some((dt, _)) = parse_dt(value, &params) {
                ev.exdates.insert(dt);
            }
        }
        _ => {}
    }
}

fn split_name_and_params(name: String) -> (String, Vec<(String, String)>) {
    let mut parts = name.split(';');
    let base = parts.next().unwrap_or("").to_string();
    let params = parts
        .filter_map(|p| p.split_once('='))
        .map(|(k, v)| (k.to_ascii_uppercase(), v.to_string()))
        .collect();
    (base, params)
}

fn unescape_text(s: &str) -> String {
    s.replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\n", "\n")
        .replace("\\\\", "\\")
}

fn parse_dt(value: &str, params: &[(String, String)]) -> Option<(NaiveDateTime, bool)> {
    let param_marks_utc = params.iter().any(|(k, v)| k == "VALUE" && v == "DATE-TIME")
        || params.iter().any(|(k, v)| k == "TZID" && v.to_uppercase() == "UTC");
    let value = value.trim();

    // Strip trailing "Z" so we can use the literal format string below.
    // (chrono's %Z is a timezone *name*, not the literal letter Z.)
    let (value, trailing_z) = value
        .strip_suffix('Z')
        .map(|v| (v, true))
        .unwrap_or((value, false));

    // RFC 3339 (works for "2026-08-25T09:00:00+00:00" etc.).
    if let Ok(dt) = DateTime::parse_from_rfc3339(value) {
        return Some((dt.naive_utc(), true));
    }

    // iCal datetime form: "20260825T090000" (with or without trailing Z).
    if let Ok(dt) = NaiveDateTime::parse_from_str(value, "%Y%m%dT%H%M%S") {
        return Some((dt, trailing_z || param_marks_utc));
    }

    // iCal date form: "20260825".
    if let Ok(d) = NaiveDate::parse_from_str(value, "%Y%m%d") {
        return Some((d.and_hms_opt(0, 0, 0)?, true));
    }

    None
}

fn parse_rrule(value: &str) -> Option<RRule> {
    let mut freq = None;
    let mut interval = 1u32;
    let mut by_day = Vec::new();
    let mut until = None;
    for part in value.split(';') {
        let (k, v) = part.split_once('=')?;
        match k.to_ascii_uppercase().as_str() {
            "FREQ" => {
                freq = Some(match v.to_ascii_uppercase().as_str() {
                    "DAILY" => Freq::Daily,
                    "WEEKLY" => Freq::Weekly,
                    _ => return None,
                });
            }
            "INTERVAL" => interval = v.parse().unwrap_or(1).max(1),
            "BYDAY" => {
                by_day = v
                    .split(',')
                    .filter_map(|d| parse_weekday(d.trim()))
                    .collect();
            }
            "UNTIL" => {
                if let Ok(dt) = DateTime::parse_from_rfc3339(v) {
                    until = Some(dt.with_timezone(&Utc));
                } else if let Ok(dt) = DateTime::parse_from_str(v, "%Y%m%dT%H%M%SZ") {
                    until = Some(dt.with_timezone(&Utc));
                } else if let Ok(d) = NaiveDate::parse_from_str(v, "%Y%m%d") {
                    until = Some(Utc.from_utc_datetime(&d.and_hms_opt(23, 59, 59)?));
                }
            }
            _ => {}
        }
    }
    Some(RRule {
        freq: freq?,
        interval,
        by_day,
        until,
    })
}

fn parse_weekday(s: &str) -> Option<Weekday> {
    match s.to_ascii_uppercase().as_str() {
        "MO" => Some(Weekday::Mon),
        "TU" => Some(Weekday::Tue),
        "WE" => Some(Weekday::Wed),
        "TH" => Some(Weekday::Thu),
        "FR" => Some(Weekday::Fri),
        "SA" => Some(Weekday::Sat),
        "SU" => Some(Weekday::Sun),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_single_vevent() {
        let ics = "BEGIN:VCALENDAR\r\n\
                   BEGIN:VEVENT\r\n\
                   SUMMARY:Algèbre linéaire\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   DTEND:20260825T100000Z\r\n\
                   END:VEVENT\r\n\
                   END:VCALENDAR\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(drafts.len(), 1);
        assert_eq!(drafts[0].title, "Algèbre linéaire");
        assert_eq!(
            drafts[0].starts_at.as_deref(),
            Some("2026-08-25T09:00:00+00:00")
        );
    }

    #[test]
    fn location_becomes_notes() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Math\r\n\
                   LOCATION:B204\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(drafts[0].title, "Math");
        assert_eq!(drafts[0].notes.as_deref(), Some("B204"));
    }

    #[test]
    fn unfolds_continuation_lines() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:This is a\r\n  long\r\n  title\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(drafts[0].title, "This is a long title");
    }

    #[test]
    fn unescapes_commas_and_semicolons() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Math\\, advanced\\; topics\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(drafts[0].title, "Math, advanced; topics");
    }

    #[test]
    fn expands_weekly_rrule() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Tuesday Class\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   RRULE:FREQ=WEEKLY;BYDAY=TU\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        // Aug 25, 2026 is a Tuesday; expanding 90 days forward through
        // Nov 5 gives exactly 11 weekly occurrences (every 7 days:
        // Aug 25, Sep 1, 8, 15, 22, 29, Oct 6, 13, 20, 27, Nov 3).
        assert_eq!(drafts.len(), 11, "got {}", drafts.len());
    }

    #[test]
    fn honours_exdate() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Daily Standup\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   RRULE:FREQ=DAILY\r\n\
                   EXDATE:20260826T090000Z\r\n\
                   EXDATE:20260827T090000Z\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        for d in &drafts {
            let s = d.starts_at.as_deref().unwrap();
            assert!(!s.starts_with("2026-08-26T"));
            assert!(!s.starts_with("2026-08-27T"));
        }
    }

    #[test]
    fn parses_all_day_event() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Holiday\r\n\
                   DTSTART;VALUE=DATE:20260825\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(
            drafts[0].starts_at.as_deref(),
            Some("2026-08-25T00:00:00+00:00")
        );
    }

    #[test]
    fn skips_unknown_rrule_freq() {
        let ics = "BEGIN:VEVENT\r\n\
                   SUMMARY:Weird\r\n\
                   DTSTART:20260825T090000Z\r\n\
                   RRULE:FREQ=MONTHLY\r\n\
                   END:VEVENT\r\n";
        let drafts = parse_ical(ics).unwrap();
        assert_eq!(drafts.len(), 1);
    }

    #[test]
    fn empty_calendar_returns_empty() {
        assert_eq!(
            parse_ical("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n")
                .unwrap()
                .len(),
            0
        );
    }
}
