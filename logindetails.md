Summary of Logins
Portal / Module	Role	Email	Password	Full Name & Description
Citizen Portal (Primary)	citizen	mithi@medal.gov	admin	Mithilesh (Citizen)
Citizen Portal	citizen	james.doe@example.com	Password123!	James Doe (General citizen reporting & feed)
Citizen Portal (Alt 1)	citizen	maria.lopez@example.com	Password123!	Maria Lopez (Citizen)
Citizen Portal (Alt 2)	citizen	olivia.iver@example.com	Password123!	Olivia Iver (Citizen)
Authority Portal	official	ward.officer@medal.gov.in	Password123!	Anitha Rajshekar (Ward 14 Officer)
Admin Portal	admin	admin@medal.gov.in	Password123!	Municipal Commissioner (Chief System Admin)
Institution (Principal)	principal	steverogers@medal.gov	Password123!	Steve Rogers (Academy Principal)
Institution (Staff)	staff	staff@medal.gov	Password123!	Sarah Jenkins (Faculty Staff)
Institution (Student 1)	student	kajolmisra@medal.gov	Password123!	Kajol Misra (SEEK Academy Student)
Institution (Student 2)	student	dilli.ganesh@medal.gov	Password123!	Dilli Ganesh (SEEK Academy Student)
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
4. Educational Institution Module
How to access: Select Institution on the welcome screen (/institution). (Citizen and Municipal Authority accounts are strictly blocked from logging into the Institution portal).
Principal Account:
Email: steverogers@medal.gov (or principal@medal.gov)
Password: Password123! (or any password $\ge$ 4 characters)
Capabilities: Oversee faculty staff, view school-wide SEEK progress, and manage department courses.
Faculty Staff Account:
Email: staff@medal.gov
Password: Password123! (or any password $\ge$ 4 characters)
Capabilities: View class rosters, invite students, and monitor student certification badges.

5. Student Portal (Institution Academy)
How to access: Select Institution on the welcome screen (`/institution`), then log in on the Student Login screen (`/login`). You can also click "Sign Up" to register a new student account (`/student/register`).

Pre-seeded Student Credentials:
- **Student 1 (Kajol Misra)**:
  - Email: `kajolmisra@medal.gov`
  - Password: `Password123!`
  - Department: Artificial Intelligence & Data Science
  - Student ID: `MED-AIDS-2024-001`
  - Reg No: `REG-2024-0891`
- **Student 2 (Dilli Ganesh)**:
  - Email: `dilli.ganesh@medal.gov`
  - Password: `Password123!`
  - Department: Computer Science & Engineering
  - Student ID: `MED-CSE-2024-042`
  - Reg No: `REG-2024-1042`

Capabilities:
- **Student Dashboard (`/student/dashboard`)**: Welcome greeting, 21-day learning streak, overall completion donut gauge (47%), 4 KPI metric cards (Certifications ready, Enrolled courses, Credits earned, Pending enrollments), UNESCO promotion modal ("Level Up Your Impact"), and daily insights with enrolled course progress.
- **Academy (`/student/academy`)**: Segmented tabs for "My Courses" (searchable list of SEEK courses 1–6 with SDG/Empathy/Leadership tags, duration, rating, dynamic action buttons) and "My Certificates" (achievement badges for streaks/progress, official verified certificate cards MED-55219-X04 & MED-1102-G12 with download action).
- **Course Details (`/student/course-detail/:courseId`)**: SEEK course objectives, UNESCO / MGIEP accreditation, syllabus, duration, language, and one-tap enrollment.
- **Pending Courses (`/student/pending-courses`)**: View recommended/pending approval courses with status badges.
- **Course Progress (`/student/course-progress`)**: Bottom tab 2 displaying module completion, lesson checkpoints, and certificate milestones.
- **Student Profile (`/student/profile`) & Edit Profile (`/student/edit-profile`)**: Profile picture upload, department & contact info, manage password modal, class preferences dialog, and logout confirmation dialog.
- **Notifications (`/student/notifications`)**: Last 7 days and Last 30 days categories with action buttons and unread counter.