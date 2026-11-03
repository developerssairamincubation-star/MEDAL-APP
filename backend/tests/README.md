# Functional tests (hermetic)

Run from `backend/`:

    ./venv/bin/python -m pytest

First-time setup: `python3.12 -m venv venv && ./venv/bin/pip install -r tests/requirements-test.txt`

* Uses a throwaway SQLite DB; the real `DATABASE_URL` is never read (the suite aborts if the engine is not SQLite).
* E-mail sender, storage and reverse geocoder are faked. Credentials are optional env vars
  (`TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_USER_PASSWORD`, `TEST_JWT_SECRET`) with throwaway defaults.
* `xfail(strict)` tests = known bug (`BUG-nn`) or missing feature (`NOT IMPLEMENTED`). See them with `-rx`;
  see the raw failures with `--runxfail`. When a bug is fixed its test XPASSes (fails the run) -> delete the marker.
* Not covered on SQLite: OTP verify/reset (naive vs aware datetimes) - needs Postgres.
