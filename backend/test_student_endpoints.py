import requests

BASE = "http://localhost:8000"

print("--- 1. Testing Student Login ---")
resp = requests.post(f"{BASE}/login", json={"email": "kajolmisra@medal.gov", "password": "Password123!"})
print("Login status:", resp.status_code)
assert resp.status_code == 200, resp.text
token = resp.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

print("\n--- 2. Testing /student/dashboard ---")
r_dash = requests.get(f"{BASE}/student/dashboard", headers=headers)
print("Dashboard status:", r_dash.status_code, r_dash.json())
assert r_dash.status_code == 200

print("\n--- 3. Testing /student/courses ---")
r_courses = requests.get(f"{BASE}/student/courses", headers=headers)
print("Courses status:", r_courses.status_code, f"Found {len(r_courses.json())} courses")
assert r_courses.status_code == 200
course_id = r_courses.json()[0]["id"]

print("\n--- 4. Testing /student/courses/{id} ---")
r_cdetail = requests.get(f"{BASE}/student/courses/{course_id}", headers=headers)
print("Course detail status:", r_cdetail.status_code, r_cdetail.json()["title"])
assert r_cdetail.status_code == 200

print("\n--- 5. Testing /student/pending-courses ---")
r_pend = requests.get(f"{BASE}/student/pending-courses", headers=headers)
print("Pending courses status:", r_pend.status_code, f"Found {len(r_pend.json())} pending")
assert r_pend.status_code == 200

print("\n--- 6. Testing /student/progress ---")
r_prog = requests.get(f"{BASE}/student/progress", headers=headers)
print("Progress status:", r_prog.status_code, f"Found {len(r_prog.json())} enrolled courses")
assert r_prog.status_code == 200

print("\n--- 7. Testing /student/certificates ---")
r_cert = requests.get(f"{BASE}/student/certificates", headers=headers)
print("Certificates status:", r_cert.status_code, f"Found {len(r_cert.json())} certs")
assert r_cert.status_code == 200

print("\n--- 8. Testing /student/notifications ---")
r_notif = requests.get(f"{BASE}/student/notifications", headers=headers)
print("Notifications status:", r_notif.status_code, r_notif.json().keys())
assert r_notif.status_code == 200

print("\n--- 9. Testing Student Registration ---")
reg_payload = {
    "name": "Aarav Sharma",
    "email": "aarav.sharma@medal.gov",
    "department": "Computer Science & Engineering",
    "student_id": "MED-CSE-2024-99",
    "registration_number": "REG-2024-0099",
    "password": "Password123!",
    "confirm_password": "Password123!"
}
r_reg = requests.post(f"{BASE}/student/register", json=reg_payload)
print("Registration status:", r_reg.status_code, r_reg.json())
assert r_reg.status_code in (201, 400), r_reg.text # 400 if already exists

print("\n--- 10. Testing Course Enrollment ---")
# Try enrolling in course 5 (Peace & Harmony)
r_enroll = requests.post(f"{BASE}/student/courses/5/enroll", headers=headers)
print("Enrollment status:", r_enroll.status_code, r_enroll.json())
assert r_enroll.status_code in (200, 400)

print("\nALL STUDENT PORTAL API TESTS PASSED SUCCESSFULLY!")
