Summary of Logins
Portal / Module	Role	Email	Password	Full Name & Description
Citizen Portal (Primary)	citizen	mithi@medal.gov	admin	Mithilesh (Citizen)
Citizen Portal	citizen	james.doe@example.com	Password123!	James Doe (General citizen reporting & feed)
Citizen Portal (Alt 1)	citizen	maria.lopez@example.com	Password123!	Maria Lopez (Citizen)
Citizen Portal (Alt 2)	citizen	olivia.iver@example.com	Password123!	Olivia Iver (Citizen)
Authority Portal	official	ward.officer@medal.gov.in	Password123!	Anitha Rajshekar (Ward 14 Officer)
Admin Portal	admin	admin@medal.gov.in	Password123!	Municipal Commissioner (Chief System Admin)
Detailed Breakdown by Portal
1. Citizen Portal
How to access: Select Citizen on the welcome screen (/citizen/login).
Credentials:
- Email: mithi@medal.gov (Password: admin) or james.doe@example.com (Password: Password123!)
Capabilities:
File civic grievance reports with photos, geolocation, and SDG alignments.
View community complaint feed, upvote, and post comments/threads.
Access the SEEK Academy modules and track filed complaints.
2. Municipal Authority / Ward Officer Portal
How to access: Log in via /authority/login (Citizen login is strictly restricted to citizen accounts; authority accounts are denied access on the citizen login page).
Credentials:
Email: ward.officer@medal.gov.in
Password: Password123!
Capabilities:
Access the Authority Dashboard (/authority/main).
Review assigned ward complaints, view citizen evidence photos, and inspect incident coordinates.
Update complaint statuses (Under Review, In Progress, Resolved, Rejected).
Attach internal officer notes and communicate in official comment threads.
3. System Administrator Portal
How to access: Click "System Administrator Login" at the bottom of the welcome screen, or navigate to /admin/login.
Credentials:
Email: admin@medal.gov.in
Password: Password123!
Capabilities:
Access the Admin Authority Applications list (/admin/applications-list).
Review pending authority registration applications, examine uploaded ID proofs (Aadhaar / Employment Gazette docs), and approve or reject authority officers.
Oversee municipal system operations.
4. Educational Institution Module (Principal, Staff, Student)
No institution accounts are pre-seeded; every figure in this portal comes from the database.
How to access: Select Institution on the welcome screen (/institution). Citizen and Municipal Authority accounts are blocked from this portal.
- Principal: provisioned once from the backend with `python create_principal.py --email <email> --password <password> --name "<name>"` (or PRINCIPAL_EMAIL / PRINCIPAL_PASSWORD / PRINCIPAL_NAME in backend/.env).
- Staff: added by the Principal from the app (Add staffs). A temporary password is generated and shown once; the teacher signs in with it.
- Students: self-register on the Student Login screen ("Sign Up", /student/register).
- Everyone takes the same SEEK course. Chapter completion is saved per user; the Principal sees staff (and student) chapter progress live, and Staff see student progress.
- Chapter content/links: backend/data/seek_course_chapters.json (loaded at startup).

