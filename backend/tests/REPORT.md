# MEDAL functional test report

> **Update:** BUG-12, 23, 24, 26, 27 and the logout gap are FIXED (see `tests/test_security_fixes.py`); BUG-12's
> sibling rules now also cover `PATCH /complaints/{id}`. Everything below that is not listed there is still open.

Run: `cd backend && ./venv/bin/python -m pytest` → **107 passed, 41 xfailed** (each xfail is a bug or a missing feature; see `-rx`; raw failures: `--runxfail`).
Backend/API only (FastAPI). Flutter UI was **not** exercised (no E2E tool in repo; none added).

## Result per item

| # | Item | Result |
|---|------|--------|
| 1 | Admin login / wrong credentials | PASS |
| 2 | Authority sign-up needs docs, status Pending, no access | PASS (BUG-01, 02, 03, 04 around it) |
| 3 | Admin list / view docs / approve / reject; approved login, rejected+pending blocked | PASS (BUG-05, 06) |
| 4 | Citizen sign-up, login, report with location | PASS (BUG-07, 08, 09, 10) |
| 5 | Nearby authorities within radius | **FAIL – not implemented** (no coordinates on officials, no radius, no distance filter). Tagging approved officials works (BUG-11) |
| 6 | Notification, status change, citizen sees update, permissions | **PARTIAL FAIL** – status change + citizen view + citizen 403 pass; **no notifications in backend**; **any official can change any complaint (BUG-12)** |
| 7 | Principal login | PASS |
| 8 | Invite teacher by e-mail, one-time/expiring link | **FAIL – not implemented** (account created instantly, temp password returned in HTTP response, nothing e-mailed). Duplicate handling PASS (BUG-16) |
| 9 | Bulk CSV + template | **FAIL – not implemented** |
| 10 | Principal dashboard real data | PARTIAL – teacher activity + course completion match DB (empty and populated); **no class performance** (no class model) |
| 11 | Teacher sees only own classes/students, ID swap | **FAIL** – no class/assignment model; teacher sees all students and school-wide dashboard (BUG-17). Own-course + student-progress views PASS |
| 12 | Student chapter completion → teacher + principal views | PASS |
| 13 | Course loading, unreachable/malformed source, re-run | PARTIAL – **no scraper exists** (JSON file loader). Re-run idempotent PASS; malformed/missing PASS (BUG-19, 20) |
| 14 | Per-user progress, certificates only after completion | PASS (BUG-19b, 20b, 21) |
| 15 | Role-based access on every route | PARTIAL – matrix PASS for admin/institution routes; BUG-22, 23, 24 |
| 16 | Logout ends session | **FAIL – no logout endpoint, tokens not revocable** (BUG-27) |

## Bugs (steps → expected vs actual → location). Severity in brackets.

**BUG-12 [HIGH]** Untagged official changes any complaint. Citizen reports + tags officer A; officer B `PATCH /complaints/{id}/status` → expected 403, got 200. `app/routers/complaint.py:601-605` (only `require_role("official","admin")`, no tag/range check). Same cause: **BUG-13** `GET /complaints` returns all complaints to every official (`complaint.py:244-250`).
**BUG-24 [HIGH]** Student/teacher/principal can read and edit every citizen complaint. Log in as student → `GET /complaints`, `GET /complaints/{id}`, `PATCH /complaints/{id}` → expected 403, got 200. `complaint.py:244, 591, 681` only special-case the `citizen` role.
**BUG-26 [HIGH, config]** `SECRET_KEY` falls back to a public hard-coded string (`app/utils/security.py:15`); the local `backend/.env` defines none, so anyone with the source can forge an admin JWT if prod is unset too. Expected: refuse to start.
**BUG-17 [MED]** Teacher `GET /institution/dashboard` returns school-wide totals and colleagues' names/activity. `app/routers/institution.py:109-130`.
**BUG-27 [MED]** No logout/revocation; also password change does not invalidate old tokens (`student.py:815`, `auth.py` reset). Old token still 200.
**BUG-06 [MED]** Rejected authority cannot re-apply: same e-mail → 400 "already registered". `authority.py:86-92`.
**BUG-09/10/16 [MED]** E-mail case: citizen `/register` stores as typed (`auth.py:117-129`), `/login` matches exactly (`auth.py:149`); staff/student/authority are lower-cased on write. `Tara@x.com` cannot log in as `tara@x.com`; `A@x`/`a@x` register twice; forgot-password lower-cases so mixed-case users never get a code (`auth.py:222`).
**BUG-22 [MED]** Anonymous endpoints: `POST /authority/upload-document` (`authority.py:31`), `GET /authority/application-status?email=` (`:144`, leaks name/designation/rejection reason), `POST /complaints/analyze-sdg` (`complaint.py:101`, runs AI pipeline), `GET /health/storage?deep=true` (`main.py:67`).
**BUG-23 [MED]** `/student/*` only needs *any* login: citizen/official/admin get 200 on `/student/dashboard` (`student.py:294` etc.).
**BUG-19b [MED]** Certificate `download_url` `/certificates/download/<no>.pdf` has no route → 404 (`student.py:704`).
**BUG-14 [MED]** Citizen can set `officer_notes` on own complaint via `PATCH /complaints/{id}` (`complaint.py:711`).
**BUG-02 [MED]** Authority document URLs are not tied to an upload; any ≥5-char string accepted (`schemas/authority.py:19-21`). **BUG-01 [LOW]** 5 spaces pass `min_length`, stored as empty (`authority.py:97-105`).
**BUG-19 [LOW]** Duplicate chapter key in the data file → IntegrityError aborts the load (`seek_chapters.py:89-115`, autoflush off). **BUG-20 [LOW]** chapters removed from the file stay forever and block 100%.
**BUG-05 [LOW]** Reject reason of spaces stored as '' (`admin.py:180`, `schemas/authority.py:62`). **BUG-07 [LOW]** category unvalidated (`complaint.py:210`; `VALID_CATEGORIES` unused). **BUG-08 [LOW]** citizen password has no minimum (`schemas/user.py:7`). **BUG-11 [LOW]** inactive official can be tagged (`complaint.py:191-198`). **BUG-15 [LOW]** stale `rejection_reason` after reopening. **BUG-20b [LOW]** certificate date = first view, not completion (`student.py:681-686`). **BUG-21 [LOW]** `study_hours` hard-coded 7 (`student.py:806`). **BUG-25 [LOW]** inactive user's token → 400 instead of 401/403 (`auth.py:99`).

## Not tested / limits
- Flutter UI and key E2E flows (no E2E tool in repo). The authority notification bell uses `MockAuthorityRepository` (hard-coded data) in `frontend/medal/lib/modules/authority/state/authority_notification_state.dart`.
- OTP verify / reset / cooldown: need Postgres (SQLite returns naive datetimes → `now > expires_at` TypeError); only "OTP e-mail sent" was tested.
- Radius boundaries (just inside/outside 2 km), invite expiry/reuse, CSV cases, large files, scraper-unreachable: feature absent; one spec test per area is marked NOT IMPLEMENTED and will XPASS once built.
- Concurrency (double-submit of chapter completion → unique-constraint 500 risk), Cloudinary/OpenAI/SMTP real integrations, real Postgres behaviour.
- Observations, not tested: students self-register with no institution link or approval, so any registrant appears in every principal's list; CORS is `*` with credentials.
