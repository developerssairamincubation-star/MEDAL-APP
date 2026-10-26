--
-- PostgreSQL database dump
--

\restrict 4DpULWCqlZr00QtTZr3MDQdlwIV06L7RmjGNWsLJHOEuufUFbBISasaBROo7IYQ

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: authority_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authority_applications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    full_name character varying(255) NOT NULL,
    official_email character varying(255) NOT NULL,
    official_phone character varying(64),
    designation character varying(255) NOT NULL,
    department character varying(255) NOT NULL,
    jurisdiction character varying(255) NOT NULL,
    identity_number character varying(64),
    clearance_level character varying(128) DEFAULT 'Level 2 (Inspection & Resolution Lead)'::character varying NOT NULL,
    aadhaar_document_url character varying(1024) NOT NULL,
    employment_document_url character varying(1024) NOT NULL,
    status character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    rejection_reason text,
    reviewed_by_id integer,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    aadhaar_public_id character varying(255),
    employment_public_id character varying(255)
);


--
-- Name: authority_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authority_applications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authority_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authority_applications_id_seq OWNED BY public.authority_applications.id;


--
-- Name: complaint_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.complaint_comments (
    id integer NOT NULL,
    complaint_id integer NOT NULL,
    user_id integer NOT NULL,
    comment text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_comment_id integer,
    is_deleted boolean DEFAULT false NOT NULL,
    image_url character varying(1024),
    image_public_id character varying(255)
);


--
-- Name: complaint_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.complaint_comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: complaint_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.complaint_comments_id_seq OWNED BY public.complaint_comments.id;


--
-- Name: complaint_reposts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.complaint_reposts (
    id integer NOT NULL,
    complaint_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: complaint_reposts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.complaint_reposts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: complaint_reposts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.complaint_reposts_id_seq OWNED BY public.complaint_reposts.id;


--
-- Name: complaint_upvotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.complaint_upvotes (
    id integer NOT NULL,
    complaint_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: complaint_upvotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.complaint_upvotes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: complaint_upvotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.complaint_upvotes_id_seq OWNED BY public.complaint_upvotes.id;


--
-- Name: complaints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.complaints (
    id integer NOT NULL,
    title character varying NOT NULL,
    description text NOT NULL,
    category character varying NOT NULL,
    status character varying NOT NULL,
    location character varying NOT NULL,
    citizen_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    image_url character varying,
    sdg_alignment character varying,
    impact_level character varying,
    equity_classification character varying,
    ai_detected_issue character varying,
    ai_issue_confidence double precision,
    ai_suggested_sdgs text,
    ai_analysis_status character varying,
    ai_analysis_timestamp timestamp with time zone,
    ai_model_version character varying,
    latitude double precision,
    longitude double precision,
    location_address character varying,
    officer_notes text,
    rejection_reason text,
    image_public_id character varying(255)
);


--
-- Name: complaints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.complaints_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: complaints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.complaints_id_seq OWNED BY public.complaints.id;


--
-- Name: password_reset_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_otps (
    id integer NOT NULL,
    user_id integer,
    email character varying NOT NULL,
    otp_hash character varying NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts_count integer NOT NULL,
    max_attempts integer NOT NULL,
    is_used boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_reset_otps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_reset_otps_id_seq OWNED BY public.password_reset_otps.id;


--
-- Name: student_certificates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_certificates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(255) NOT NULL,
    certificate_no character varying(128) NOT NULL,
    completed_date_str character varying(64) NOT NULL,
    issuing_institution character varying(128) NOT NULL,
    badge_type character varying(64) NOT NULL,
    download_url character varying(512),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    certificate_public_id character varying(255)
);


--
-- Name: student_certificates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_certificates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_certificates_id_seq OWNED BY public.student_certificates.id;


--
-- Name: student_courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_courses (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    provider character varying(128) NOT NULL,
    department character varying(128) NOT NULL,
    category character varying(64) NOT NULL,
    duration character varying(64) NOT NULL,
    rating double precision NOT NULL,
    description text NOT NULL,
    what_you_will_learn text,
    language character varying(64) NOT NULL,
    certificate_available boolean NOT NULL,
    enrollment_deadline character varying(64),
    deadline_remaining_text character varying(64),
    image_url character varying(512),
    total_modules integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: student_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_courses_id_seq OWNED BY public.student_courses.id;


--
-- Name: student_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_enrollments (
    id integer NOT NULL,
    user_id integer NOT NULL,
    course_id integer NOT NULL,
    status character varying(32) NOT NULL,
    progress_pct double precision NOT NULL,
    completed_modules integer NOT NULL,
    start_date character varying(64),
    end_date character varying(64),
    credits_earned integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: student_enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_enrollments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_enrollments_id_seq OWNED BY public.student_enrollments.id;


--
-- Name: student_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    category character varying(64) NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    period_group character varying(32) NOT NULL,
    is_read boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: student_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_notifications_id_seq OWNED BY public.student_notifications.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying NOT NULL,
    password_hash character varying NOT NULL,
    full_name character varying NOT NULL,
    phone character varying,
    role character varying NOT NULL,
    is_verified boolean NOT NULL,
    is_active boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    profile_image_url character varying,
    approval_status character varying(32) DEFAULT 'approved'::character varying NOT NULL,
    designation character varying(255),
    department character varying(255),
    jurisdiction character varying(255),
    clearance_level character varying(128),
    student_id character varying(64),
    registration_number character varying(64),
    preferences character varying(512),
    profile_image_public_id character varying(255)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: authority_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authority_applications ALTER COLUMN id SET DEFAULT nextval('public.authority_applications_id_seq'::regclass);


--
-- Name: complaint_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_comments ALTER COLUMN id SET DEFAULT nextval('public.complaint_comments_id_seq'::regclass);


--
-- Name: complaint_reposts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_reposts ALTER COLUMN id SET DEFAULT nextval('public.complaint_reposts_id_seq'::regclass);


--
-- Name: complaint_upvotes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_upvotes ALTER COLUMN id SET DEFAULT nextval('public.complaint_upvotes_id_seq'::regclass);


--
-- Name: complaints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaints ALTER COLUMN id SET DEFAULT nextval('public.complaints_id_seq'::regclass);


--
-- Name: password_reset_otps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps ALTER COLUMN id SET DEFAULT nextval('public.password_reset_otps_id_seq'::regclass);


--
-- Name: student_certificates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_certificates ALTER COLUMN id SET DEFAULT nextval('public.student_certificates_id_seq'::regclass);


--
-- Name: student_courses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_courses ALTER COLUMN id SET DEFAULT nextval('public.student_courses_id_seq'::regclass);


--
-- Name: student_enrollments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_enrollments ALTER COLUMN id SET DEFAULT nextval('public.student_enrollments_id_seq'::regclass);


--
-- Name: student_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_notifications ALTER COLUMN id SET DEFAULT nextval('public.student_notifications_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.alembic_version (version_num) FROM stdin;
e5f6a7b8c9d0
\.


--
-- Data for Name: authority_applications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.authority_applications (id, user_id, full_name, official_email, official_phone, designation, department, jurisdiction, identity_number, clearance_level, aadhaar_document_url, employment_document_url, status, rejection_reason, reviewed_by_id, reviewed_at, created_at, updated_at, aadhaar_public_id, employment_public_id) FROM stdin;
\.


--
-- Data for Name: complaint_comments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.complaint_comments (id, complaint_id, user_id, comment, created_at, parent_comment_id, is_deleted, image_url, image_public_id) FROM stdin;
1	110	3	hi	2026-09-23 14:49:16.077529+05:30	\N	f	\N	\N
2	110	3	hello	2026-09-23 14:49:24.261783+05:30	1	f	\N	\N
3	101	20	Yes, It have come to our observation that this issue has been a big concern and it is really bothering the thought of health. @RamyaGovindhan please take action.	2026-09-23 14:40:48.945118+05:30	\N	f	\N	\N
4	101	21	The issue will be addressed soon.	2026-09-23 14:53:48.950133+05:30	3	f	\N	\N
6	101	3	hii	2026-09-23 15:32:36.440807+05:30	4	f	\N	\N
7	101	3	hoo	2026-09-24 09:35:47.271362+05:30	5	f	\N	\N
9	101	3	sure	2026-09-24 09:36:16.714336+05:30	4	f	\N	\N
5	101	3	This comment was deleted	2026-09-23 15:32:28.640478+05:30	3	t	\N	\N
13	101	22	hi	2026-09-24 15:51:58.169388+05:30	\N	f	\N	\N
15	101	22	@JamesDoe helloo	2026-09-25 09:44:44.301433+05:30	5	f	\N	\N
19	101	22	@LisaGodwin nnhgnrehrk	2026-10-14 11:47:30.271896+05:30	3	f	\N	\N
20	101	22	[Image Attachment]	2026-10-14 12:24:56.574923+05:30	\N	f	\N	\N
22	140	53	I pass here every day, water levels are indeed very high!	2026-10-26 23:30:00.213534+05:30	\N	f	\N	\N
23	140	52	Thanks Bob, I have informed the local ward office as well.	2026-10-26 23:30:00.223145+05:30	\N	f	\N	\N
24	144	22	yes	2026-10-26 23:47:10.94187+05:30	\N	f	\N	\N
25	144	5	@Mithilesh yes need to fix this	2026-10-26 23:49:16.638529+05:30	24	f	\N	\N
26	144	5	fix this issue ⚠️ ⚠️	2026-10-26 23:49:38.077293+05:30	\N	f	\N	\N
\.


--
-- Data for Name: complaint_reposts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.complaint_reposts (id, complaint_id, user_id, created_at) FROM stdin;
9	101	22	2026-10-23 06:19:05.681221+05:30
\.


--
-- Data for Name: complaint_upvotes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.complaint_upvotes (id, complaint_id, user_id, created_at) FROM stdin;
1	101	4	2026-09-18 08:11:13.877417+05:30
2	101	5	2026-09-18 08:56:13.877417+05:30
3	103	3	2026-09-18 07:41:13.877417+05:30
4	103	4	2026-09-18 08:41:13.877417+05:30
5	104	5	2026-09-18 09:26:13.877417+05:30
7	105	7	2026-09-18 09:41:37.425926+05:30
8	105	8	2026-09-18 09:41:37.44494+05:30
9	110	16	2026-09-18 09:48:47.524961+05:30
10	110	3	2026-09-23 14:49:08.928047+05:30
11	101	3	2026-09-23 15:32:18.952253+05:30
18	117	27	2026-09-25 11:48:30.490389+05:30
19	117	28	2026-09-25 11:48:30.50039+05:30
22	118	22	2026-10-06 13:50:41.17022+05:30
33	137	38	2026-10-06 15:13:12.697875+05:30
35	101	22	2026-10-14 12:11:14.446523+05:30
37	141	54	2026-10-26 23:30:10.846056+05:30
38	141	55	2026-10-26 23:30:10.853448+05:30
39	144	22	2026-10-26 23:47:06.841231+05:30
40	144	5	2026-10-26 23:49:02.432535+05:30
\.


--
-- Data for Name: complaints; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.complaints (id, title, description, category, status, location, citizen_id, created_at, updated_at, image_url, sdg_alignment, impact_level, equity_classification, ai_detected_issue, ai_issue_confidence, ai_suggested_sdgs, ai_analysis_status, ai_analysis_timestamp, ai_model_version, latitude, longitude, location_address, officer_notes, rejection_reason, image_public_id) FROM stdin;
109	Waste pile 8aac1a5f	Garbage overflow near school	garbage	submitted	Opposite Primary School	13	2026-06-04 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	\N	\N	High	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
110	Dangerous Open Drainage Trench 25e45802	Exposed concrete drainage trench overflowing near community market.	drainage	resolved	Anna Nagar 3rd Avenue, Ward 10	15	2026-06-03 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	/uploads/reports/967e0adc797341f3949a00a754704ac7.jpg	SDG 6: Clean Water and Sanitation	High	Commercial District	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
117	Broken streetlights on Ring Road 0621ee6b	Entire 200m stretch is completely dark at night	streetlight	submitted	Ring Road Sector 7	27	2026-09-25 11:48:30.368138+05:30	2026-09-25 11:48:30.368138+05:30	\N	\N	High	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
111	Broken Drainage Channel near Market Road	Severe sewage overflow causing sanitation hazard across market entrance.	drainage	submitted	Market Road, Sector 3	19	2026-06-02 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	http://localhost:9000/medal-evidence/reports/29acf35f9ebe4dfc89d5e15cfca7c754.jpg	SDG 6: Clean Water and Sanitation	High	Commercial District	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
118	Garbage Dump	garbage is dumped around the school premises	garbage_&_solid_waste	submitted	2nd street, medavakkam	22	2026-09-25 11:55:14.242035+05:30	2026-09-25 11:55:14.242035+05:30	http://localhost:9000/medal-evidence/reports/bc63962a073a4e5f964e90d4144c3238.jpg	SDG 8: Decent Work and Economic Growth	Medium	Standard Urban Zone	\N	\N	\N	unknown	\N	yolo26n.pt	\N	\N	\N	\N	\N	\N
102	Streetlight Cluster Outage on 5th Cross Road	Street light outage at the main intersection has been fixed. Visibility is much better now for pedestrians.	streetlight	resolved	Park street	4	2026-09-23 04:32:57.092313+05:30	2026-09-23 15:02:57.098319+05:30	\N	SDG 11	Medium	School / Hospital Vicinity	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
104	Drinking Water Pipeline Burst near Community Park	Clean municipal potable water gushing on the road since morning, wasting thousands of liters while surrounding homes experience zero water pressure.	water	submitted	Near Children Community Park, Ward 11	3	2026-06-09 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	http://localhost:9000/medal-evidence/reports/sample_water_leak.jpg	SDG 6: Clean Water and Sanitation	High	Public Park / Community Space	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
105	Broken streetlights on Ring Road 4de3751a	Entire 200m stretch is completely dark at night	streetlight	submitted	Ring Road Sector 7	7	2026-06-08 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	\N	\N	High	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
101	Critical Canal Junction Waste Blockage	Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.	garbage	in_progress	Bharathiyar street	3	2026-09-23 07:32:57.091727+05:30	2026-10-26 23:18:14.245445+05:30	https://res.cloudinary.com/uco2jihi/image/upload/v1793036893/medal/complaints/asset_2472f45a724a47efae333af557860035.jpg	SDG 13	High	Vulnerable Low-Income Neighborhood	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	medal/complaints/asset_2472f45a724a47efae333af557860035
107	Broken Water Main e40b4727	Massive pipeline rupture causing street flood	water	resolved	Ward 12, Main Road	11	2026-06-06 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	\N	\N	High	Hospital Corridor	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
108	Pothole cluster 8aac1a5f	Hazardous road condition on main street	road	submitted	Main Street Junction	13	2026-06-05 09:33:41.088026+05:30	2026-09-23 15:03:41.08901+05:30	\N	\N	Medium	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
119	Water Pollution	water is polluted	drainage_&_sewage	submitted	2nd street, medavakkam	22	2026-09-25 11:57:01.397402+05:30	2026-09-25 11:57:01.397402+05:30	http://localhost:9000/medal-evidence/reports/2ad70ae64dc34f4ab410b038baab860c.jpg	SDG 8: Decent Work and Economic Growth	Medium	Standard Urban Zone	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
120	Damaged Government Buildings	the government building is damaged	educational_infrastructure	submitted	2nd street, medavakkam	22	2026-09-25 12:00:16.630281+05:30	2026-09-25 12:00:16.630281+05:30	http://localhost:9000/medal-evidence/reports/5acf3edd1c0148aa91adc984d4e6dc69.jpg	SDG 11: Sustainable Cities and Communities	Medium	Standard Urban Zone	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
103	Deep Pothole Crater near General Hospital Gate 2	Critical road management failure observed at the Naidu street junction. Local community impact rising due to lack of observation and poor quality.	road	in_progress	Bharathiyar street	5	2026-09-22 21:32:57.093319+05:30	2026-10-26 23:18:15.779325+05:30	https://res.cloudinary.com/uco2jihi/image/upload/v1793036894/medal/complaints/asset_7ae8561c6d7641b5acfc427f9f631846.jpg	SDG 8	Critical	Emergency Route / Hospital Zone	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	medal/complaints/asset_7ae8561c6d7641b5acfc427f9f631846
129	Garbage	heloooo	garbage_&_solid_waste	submitted	2nd street, medavakkam	22	2026-09-25 13:52:00.974534+05:30	2026-09-25 13:52:00.974534+05:30	http://localhost:9000/medal-evidence/reports/bb72f473a1874cb39c54054927b28f62.jpg	\N	Medium	Standard Urban Zone	\N	\N	\N	unknown	\N	yolo26n.pt	\N	\N	\N	\N	\N	\N
137	Dangerous Open Manhole near Primary School 9c7479a9	Uncovered drain manhole with high risk of fall injury for schoolchildren during evening hours.	drainage	resolved	Opposite St. Jude Primary School, Ward 15	37	2026-10-06 15:13:12.092445+05:30	2026-10-06 15:13:13.305218+05:30	http://localhost:9000/medal-evidence/reports/846d109b91d746419ce0e92b42f54983.jpg	SDG 11: Sustainable Cities and Communities	Critical	School / Hospital Vicinity	\N	\N	\N	\N	\N	\N	\N	\N	Opposite St. Jude Primary School, Ward 15	\N	\N	\N
140	Broken storm drain flooding road	Severe overflow during rain at junction 4.	drainage	submitted	North Canal Road	52	2026-10-26 23:30:00.190721+05:30	2026-10-26 23:30:00.190721+05:30	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	North Canal Road	\N	\N	\N
141	Broken streetlights on Ring Road e91247ef	Entire 200m stretch is completely dark at night	streetlight	submitted	Ring Road Sector 7	54	2026-10-26 23:30:10.785824+05:30	2026-10-26 23:30:10.785824+05:30	\N	\N	High	\N	\N	\N	\N	\N	\N	\N	\N	\N	Ring Road Sector 7	\N	\N	\N
142	Severe Water Main Leakage opposite Hospital Gate	Massive clean water wastage flowing down the street, creating hazardous road conditions and flooding nearby pedestrian paths.	water	submitted	Opposite General Hospital Gate 3, Sector 4	57	2026-10-26 23:31:56.705188+05:30	2026-10-26 23:31:56.705188+05:30	https://res.cloudinary.com/uco2jihi/image/upload/v1793037716/medal/complaints/asset_69020a337879414a90d79a4366ce102a.jpg	SDG 6: Clean Water and Sanitation	High	School / Hospital Vicinity	\N	\N	\N	\N	\N	\N	\N	\N	Opposite General Hospital Gate 3, Sector 4	\N	\N	\N
143	Broken Streetlight at Corner	Streetlight pole flickering and wire exposed near intersection.	streetlight	submitted	2nd Street, Medavakkam, Chennai, Tamil Nadu	57	2026-10-26 23:31:56.733164+05:30	2026-10-26 23:31:56.733164+05:30	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	12.917142	80.192384	2nd Street, Medavakkam, Chennai, Tamil Nadu	\N	\N	\N
144	Garbage	garbage dumped in Tambaram Bus Stand	garbage_&_solid_waste	submitted	Lat: 12.927161, Lng: 80.155070	22	2026-10-26 23:46:58.250263+05:30	2026-10-26 23:46:58.250263+05:30	https://res.cloudinary.com/uco2jihi/image/upload/v1793038617/medal/complaints/asset_29d55c0d4ac247af9ebb68f48bf53a1a.jpg	SDG 8: Decent Work and Economic Growth	Medium	Standard Urban Zone	\N	\N	\N	\N	\N	\N	12.927160638515769	80.15506985255199	Lat: 12.927161, Lng: 80.155070	\N	\N	\N
\.


--
-- Data for Name: password_reset_otps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_reset_otps (id, user_id, email, otp_hash, expires_at, attempts_count, max_attempts, is_used, created_at) FROM stdin;
\.


--
-- Data for Name: student_certificates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.student_certificates (id, user_id, title, certificate_no, completed_date_str, issuing_institution, badge_type, download_url, created_at, certificate_public_id) FROM stdin;
4	41	SEEK Foundation & Ecological Awareness	MED-55219-X04	COMPLETED MAY 2024	Academic Excellence Academy	verified	\N	2026-10-25 16:11:01.216594+05:30	\N
5	41	Community Empathy & Civic Problem Discovery	MED-1102-G12	COMPLETED FEB 2024	Academic Excellence Academy	star	\N	2026-10-25 16:11:01.216594+05:30	\N
6	42	SEEK Foundation & Ecological Awareness	MED-55219-X05	COMPLETED MAY 2024	Academic Excellence Academy	verified	\N	2026-10-25 16:11:01.216594+05:30	\N
7	42	Community Empathy & Civic Problem Discovery	MED-1102-G13	COMPLETED FEB 2024	Academic Excellence Academy	star	\N	2026-10-25 16:11:01.216594+05:30	\N
\.


--
-- Data for Name: student_courses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.student_courses (id, title, provider, department, category, duration, rating, description, what_you_will_learn, language, certificate_available, enrollment_deadline, deadline_remaining_text, image_url, total_modules, created_at) FROM stdin;
1	SEEK COURSE 1	UNESCO	Foundational Learning	SDG 15	4h	4.9	Foundational socio-emotional and environmental knowledge course covering biodiversity, ecosystem resilience, and sustainable community leadership.	SEEK basics and key concepts\nEcosystem resilience models\nHands-on community reporting\nGlobal sustainability guidelines	English	t	26 October 2026	Completed	assets/images/sample_mountain.jpg	5	2026-10-25 16:10:38.004227+05:30
2	SEEK COURSE 2	UNESCO	Social Sciences	EMPATHY	6h	4.7	Empathy-driven social innovation and citizen action for municipal problem diagnosis and collaborative civic problem-solving.	Empathy-driven problem discovery\nCommunity interview techniques\nStakeholder mapping\nEthics in civic participation	English	t	30 October 2026	In Progress	assets/images/sample_chart.jpg	6	2026-10-25 16:10:38.004227+05:30
3	SEEK COURSE 3	UNESCO	Public Policy	LEADERSHIP	3h	4.8	Strategic leadership in youth governance, evidence collation, and SDG-aligned public advocacy campaigns.	Youth leadership strategies\nEvidence verification fundamentals\nPolicy alignment frameworks\nDigital public engagement	English	t	15 November 2026	Open	assets/images/sample_team.jpg	4	2026-10-25 16:10:38.004227+05:30
4	SEEK COURSE 4	UNESCO	Ethics & Civic Wellness	MINDFULNESS	4 Weeks	4.6	Learn the fundamentals of SEEK, from key concepts to real-world applications and best practices in public institutional welfare.	SEEK basics and key concepts\nPopular SEEK service models\nHands-on labs with real-world tools\nSecurity and scalability best practices	English	t	25 October 2026	2 days left	assets/images/sample_building.jpg	4	2026-10-25 16:10:38.004227+05:30
5	SEEK COURSE 5	UNESCO	Urban Ecology	SDG 11	3 Weeks	4.8	Urban ecological interventions and smart municipal complaint monitoring frameworks for sustainable cities.	Smart urban infrastructure\nWaste stream monitoring\nRenewable community grids\nPublic grievance management	English	t	05 November 2026	11 days left	assets/images/sample_mountain.jpg	4	2026-10-25 16:10:38.004227+05:30
6	SEEK COURSE 6	UNESCO	Data Science	ANALYTICS	5 Weeks	4.9	Advanced analytics and geospatial telemetry data interpretation for evidence-based governance.	Geospatial data mapping\nEvidence verification pipelines\nPredictive maintenance alerts\nStatistical impact quantification	English	t	20 November 2026	26 days left	assets/images/sample_chart.jpg	5	2026-10-25 16:10:38.004227+05:30
\.


--
-- Data for Name: student_enrollments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.student_enrollments (id, user_id, course_id, status, progress_pct, completed_modules, start_date, end_date, credits_earned, created_at) FROM stdin;
1	41	1	completed	1	5	06 Oct 2026	26 Oct 2026	60	2026-10-25 16:11:01.223079+05:30
2	41	2	enrolled	0.32	2	09 Oct 2026	30 Oct 2026	55	2026-10-25 16:11:01.223079+05:30
3	41	3	enrolled	0.1	1	12 Oct 2026	15 Nov 2026	0	2026-10-25 16:11:01.223079+05:30
6	42	1	completed	1	5	06 Oct 2026	26 Oct 2026	60	2026-10-25 16:11:01.223079+05:30
7	42	2	enrolled	0.32	2	09 Oct 2026	30 Oct 2026	55	2026-10-25 16:11:01.223079+05:30
8	42	3	enrolled	0.1	1	12 Oct 2026	15 Nov 2026	0	2026-10-25 16:11:01.223079+05:30
10	42	5	pending	0	0	\N	\N	0	2026-10-25 16:11:01.223079+05:30
11	43	1	enrolled	0	0	25 Oct 2026	30 Nov 2026	0	2026-10-25 16:44:13.077752+05:30
5	41	5	enrolled	0	0	\N	\N	0	2026-10-25 16:11:01.223079+05:30
9	42	4	enrolled	0	0	\N	\N	0	2026-10-25 16:11:01.223079+05:30
4	41	4	enrolled	0	0	\N	\N	0	2026-10-25 16:11:01.223079+05:30
\.


--
-- Data for Name: student_notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.student_notifications (id, user_id, category, title, description, period_group, is_read, created_at) FROM stdin;
1	41	Academy	Course Progress Reminder	Course 20% pending... we would love to see your progress	last_7_days	f	2026-10-25 16:11:01.228072+05:30
2	41	Certificate Issued	Certificate Issued	3 certificates have been issued	last_7_days	f	2026-10-25 16:11:01.228072+05:30
3	41	Academy	Course Completion	Course 1 successfully completed. View the certificate	last_30_days	f	2026-10-25 16:11:01.228072+05:30
4	41	Streak Maintenance	Streak Maintenance	Continuous 21 days of streaks maintained	last_30_days	f	2026-10-25 16:11:01.228072+05:30
5	41	Learning Spree	Learning Spree	Learning is being spontaneous	last_30_days	f	2026-10-25 16:11:01.228072+05:30
6	42	Academy	Course Progress Reminder	Course 20% pending... we would love to see your progress	last_7_days	f	2026-10-25 16:11:01.228072+05:30
7	42	Certificate Issued	Certificate Issued	3 certificates have been issued	last_7_days	f	2026-10-25 16:11:01.228072+05:30
8	42	Academy	Course Completion	Course 1 successfully completed. View the certificate	last_30_days	f	2026-10-25 16:11:01.228072+05:30
9	42	Streak Maintenance	Streak Maintenance	Continuous 21 days of streaks maintained	last_30_days	f	2026-10-25 16:11:01.228072+05:30
10	42	Learning Spree	Learning Spree	Learning is being spontaneous	last_30_days	f	2026-10-25 16:11:01.228072+05:30
11	43	Academy	Welcome to SEEK Academy	Your institutional account is verified. Start your foundational SEEK course.	last_7_days	f	2026-10-25 16:44:13.088748+05:30
12	41	Academy	Enrollment Confirmed	Successfully enrolled in SEEK COURSE 5. Start learning your modules today.	last_7_days	f	2026-10-25 16:44:15.173849+05:30
13	42	Academy	Enrollment Confirmed	Successfully enrolled in SEEK COURSE 4. Start learning your modules today.	last_7_days	f	2026-10-25 17:08:18.647051+05:30
14	41	Academy	Enrollment Confirmed	Successfully enrolled in SEEK COURSE 4. Start learning your modules today.	last_7_days	f	2026-10-25 17:18:15.54897+05:30
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password_hash, full_name, phone, role, is_verified, is_active, created_at, profile_image_url, approval_status, designation, department, jurisdiction, clearance_level, student_id, registration_number, preferences, profile_image_public_id) FROM stdin;
29	ai_user_672319f2@example.com	$2b$12$kS3FPGVYZ.ZWJ5Atp67/Ke4JMr5rWTvXLXbup6h3jFne6d0Hn6keq	AI Tester 672319f2	9876543210	citizen	f	t	2026-09-25 12:33:53.67361+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
6	profile_user_2c56ec4f@example.com	$2b$12$oojWkf/vrJPiC/BKotLZ9.z3yrgPEiVfn43Apza4dZcJm93OESQp.	Honest Citizen	9998887776	citizen	f	t	2026-09-18 09:41:26.630593+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
7	citizen_a_4de3751a@example.com	$2b$12$8UIGTCos8t4VUpETGaAIw.MgQaEUIan9so39Bw0nUJa5ozwQE5Ndm	Citizen Alice	9111111111	citizen	f	t	2026-09-18 09:41:36.097728+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
8	citizen_b_4de3751a@example.com	$2b$12$HUfHMw9QDbmJIO8IRJUZ1OtJN/Pu5K8E2EK8u58x/eQmvNzyviVyO	Citizen Bob	9222222222	citizen	f	t	2026-09-18 09:41:36.51622+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
9	reporter_257185d2@example.com	$2b$12$ezI5/YdXDd4kJRqvvZDpWOAjkq93NOVtxYOQP9tNdKPjCUim9UP6S	Reporter Citizen 257185d2	9988776655	citizen	f	t	2026-09-18 09:41:46.274909+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
10	reporter_70113ba2@example.com	$2b$12$F23aKqBLD8UBe6AEmeuWr.8CC9J4ASGLmZgS8JB7cvQrCRMmGs2Vu	Reporter Citizen 70113ba2	9988776655	citizen	f	t	2026-09-18 09:43:48.669825+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
11	citizen_wf_e40b4727@example.com	$2b$12$SARkFxGHgFdBaZ5F9G4Vx.KmZ/z8kADwZGn7kEwHkV2Wxwiy0EBW.	Citizen User	9000000001	citizen	f	t	2026-09-18 09:44:12.122866+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
12	official_wf_e40b4727@example.com	$2b$12$IkhfIcSONbMw75hpLLB.wOwdx/PvtvGpTAVXODtVDbYlFJSN6gkoO	Ward Engineer Anitha	9000000002	official	f	t	2026-09-18 09:44:12.517146+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
13	feed_user_8aac1a5f@example.com	$2b$12$9qu/BxqxFRvEj6Pq48XFPOnQNtgkfs06nAh/vUTthldLv7ZTmIJVC	Ravi Kumar	9123456780	citizen	f	t	2026-09-18 09:44:44.933169+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
14	live_citizen_dad07eff@medal.app	$2b$12$QumLYnbMmzrbjNyyzRVWBeNM.EE2M.lFb4A3uKsx5H4M17ehx1BD6	Senthil Nathan	9841011223	citizen	f	t	2026-09-18 09:47:14.513917+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
16	live_peer_25e45802@medal.app	$2b$12$mJwXYVdm0cFIgrewDzuC.ew.EM2qzkd7z4Zc5qYXpif4t9i/9CbkK	Priya Ramesh	9841998877	citizen	f	t	2026-09-18 09:48:47.079509+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
15	live_citizen_25e45802@medal.app	$2b$12$kAibAEsTYlvtfPB.EtG4AuPSr7EkWZn8iWTD8.Lfh1528t/bJnDni	Senthil Nathan K.	9841099999	citizen	f	t	2026-09-18 09:48:45.943948+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
17	live_official_25e45802@medal.gov.in	$2b$12$5PR42N6Othr1gCfKspEgaOkeiLJGiphJzqv.hLZUW4wq0h45KoQaG	Ward Inspector Rajesh	9841055555	official	f	t	2026-09-18 09:48:47.998461+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
1	admin@medal.gov.in	$2b$12$d36zoHto1JIvZIJZZsKfteqEa/o2bEEioqjP.sC4zobRvpbvZLKZu	Municipal Commissioner	+91 9876543210	admin	t	t	2026-08-19 09:41:13.877417+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
2	ward.officer@medal.gov.in	$2b$12$d36zoHto1JIvZIJZZsKfteqEa/o2bEEioqjP.sC4zobRvpbvZLKZu	Anitha Rajshekar (Ward 14 Officer)	+91 9876543211	official	t	t	2026-08-24 09:41:13.877417+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
3	james.doe@example.com	$2b$12$d36zoHto1JIvZIJZZsKfteqEa/o2bEEioqjP.sC4zobRvpbvZLKZu	James Doe	+91 9876543212	citizen	t	t	2026-08-29 09:41:13.877417+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
4	maria.lopez@example.com	$2b$12$d36zoHto1JIvZIJZZsKfteqEa/o2bEEioqjP.sC4zobRvpbvZLKZu	Maria Lopez	+91 9876543213	citizen	t	t	2026-09-03 09:41:13.877417+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
5	olivia.iver@example.com	$2b$12$d36zoHto1JIvZIJZZsKfteqEa/o2bEEioqjP.sC4zobRvpbvZLKZu	Olivia Iver	+91 9876543214	citizen	t	t	2026-09-08 09:41:13.877417+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
18	admin@medal.gov	$2b$12$uwhjhLzn.C3i8ZkXJgCEh.MrpTCqC0OGo5jzF7NCiZtrV6AoS7TEq	Admin	\N	citizen	f	t	2026-09-18 11:58:25.04818+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
19	minio_tester_e72efe82@example.com	$2b$12$503MPafZjUn3Xf4vHS1b0OhiCMm5ck2bBqmjJZbIIIOzZDx6bzsy2	MinIO Citizen Tester	9876543210	citizen	f	t	2026-09-23 14:57:20.135372+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
20	lisa.godwin@example.com	x	Lisa Godwin	\N	citizen	t	t	2026-09-23 15:04:48.93713+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
21	ramya.govindhan@example.com	x	Ramya Govindhan	\N	official	t	t	2026-09-23 15:04:48.941132+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
30	ai_user_ff05b48d@example.com	$2b$12$lZ6YdYrupmekV2q/r1rPeOt5OYEJF9NfmTZI8RPny9jJIpSIK8CqK	AI Tester ff05b48d	9876543210	citizen	f	t	2026-09-25 13:39:33.64858+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
23	ai_user_afea6280@example.com	$2b$12$w7wXA4fM/Zqx6S7XMnwd5OsE2pcu6KbyMYt0QeOLUzVCJZODcpaVO	AI Tester afea6280	9876543210	citizen	f	t	2026-09-25 11:38:10.565214+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
24	reporter_8863f4f4@example.com	$2b$12$Njh/OOh6zVwFtaPH601jW.AoNNYfKN27I58DQymcVH8hb40Ps4/na	Reporter Citizen 8863f4f4	9988776655	citizen	f	t	2026-09-25 11:38:24.505136+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
25	ml_tester@example.com	$2b$12$pq3n.1g0PjyE8k0RQsScM.i.N9Hrhsc6L1IPGl9rRx2OrAC3emoH2	ML Tester	9998887776	citizen	f	t	2026-09-25 11:45:02.133157+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
26	ai_user_3b0ca47d@example.com	$2b$12$aBtC53f5buBZ8/eRQQcbxOvM1tZwf/LROY9U.jGObLQct6tf1/tVy	AI Tester 3b0ca47d	9876543210	citizen	f	t	2026-09-25 11:48:05.633224+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
27	citizen_a_0621ee6b@example.com	$2b$12$c7/UZaBXTkHgirAL02dO2.TUNz.XifcRHkRYFGiR/CgiOwNdTzyhm	Citizen Alice	9111111111	citizen	f	t	2026-09-25 11:48:29.415387+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
28	citizen_b_0621ee6b@example.com	$2b$12$8qISTHVJaY/c4nPvSKvNVueBaHBQAZ99olFUnOSZrUu1rBVvmBA1e	Citizen Bob	9222222222	citizen	f	t	2026-09-25 11:48:29.73354+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
31	ai_user_857b8469@example.com	$2b$12$Saelm0TdVmo0uxbGncQ2N.KNUNEn1wb2mffVtHGgW7J3pNVKn0Nqa	AI Tester 857b8469	9876543210	citizen	f	t	2026-09-25 13:40:00.881576+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
41	kajolmisra@medal.gov	$2b$12$YR/fMgZTb412j71qfX5TSu2ZvmYl19WhDE4UiZfs/tfYzTJ2EYmwm	Kajol Misra	+91 93870 98213	student	t	t	2026-10-25 16:10:37.565433+05:30	\N	approved	\N	Mathematics Department	\N	\N	med24cs123	24123456789	Maths , Physics , Biology	\N
32	ai_user_86c24cbd@example.com	$2b$12$LbsU.5G4ahEgNRuOde8DDefGgzkcXsIqGkYWLlqCn8/IvkHz0Gmzy	AI Tester 86c24cbd	9876543210	citizen	f	t	2026-09-25 13:48:51.249389+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
33	ai_user_054b09d3@example.com	$2b$12$iZt4dDHJi8mqYdFP6TaeKerCIfimnotyg0LPpo.lzF6uSRJ6RICM2	AI Tester 054b09d3	9876543210	citizen	f	t	2026-09-25 14:11:42.865578+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
34	reporter_2bb6f214@example.com	$2b$12$PrjBjLB5Yaq4WFCnOShk2eMTsAdBT4sVcCws0juLcvRqm1Wbkhzu6	Reporter Citizen 2bb6f214	9988776655	citizen	f	t	2026-10-06 14:52:06.013217+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
35	reporter_532460e0@example.com	$2b$12$oN7nVso0xJtvY/TI3YFy.OUkLoju4jt6tuf9CgCS9P4.1tcD/N9rW	Reporter Citizen 532460e0	9988776655	citizen	f	t	2026-10-06 15:12:27.029961+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
36	reporter_546749ea@example.com	$2b$12$XbVxX67TdN6tqSMb1WfQYO9vLDrKVvialrqoJi8SbEbd4C/1sBh32	Reporter Citizen 546749ea	9988776655	citizen	f	t	2026-10-06 15:12:58.843611+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
37	e2e_citizen_9c7479a9@example.com	$2b$12$zbyt/0ylbKJWGHwzhOscg.REElpuX9x.La9yMFRuzoR/3WqS47VG2	Arun Kumar Sundaram	9840999999	citizen	f	t	2026-10-06 15:13:11.393177+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
38	e2e_peer_9c7479a9@example.com	$2b$12$P7bv8LLN0zug/Pgq/1ygGerdBBOFl2MvsP7EHdOi/99tsLwUX1LBG	Pooja Raman	9840888888	citizen	f	t	2026-10-06 15:13:12.400529+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
39	e2e_official_9c7479a9@example.com	$2b$12$NSDt9I0WIQaDt3ficLY9u.rnaJ6T9Xr1X6/kpAdRPf44X6jxcxFgK	Engineer Divya	9840777777	official	f	t	2026-10-06 15:13:12.985738+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
40	reporter_11600e00@example.com	$2b$12$r819PhfzAM.l9f.ff1lWxOGixBb0V3I.SGrnnKEpGgHLf2Yd9CfVa	Reporter Citizen 11600e00	9988776655	citizen	f	t	2026-10-07 09:51:51.321717+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
42	dilli.ganesh@medal.gov	$2b$12$.OWTTyuPj2kWHk1y0AuNAO4oh0TxWlA9AjD4rrw4CDPz/U4Y4mKM6	Dilli Ganesh	+91 98401 23456	student	t	t	2026-10-25 16:10:37.967995+05:30	\N	approved	\N	Computer Science	\N	\N	med24cs101	24123456701	Computer Science , AI	\N
43	aarav.sharma@medal.gov	$2b$12$gdA8kjViUTlO05T1E3HEquALkrmcRe9i4BGygiuEYUZjkZMeD4Lea	Aarav Sharma	\N	student	t	t	2026-10-25 16:44:13.020396+05:30	\N	approved	\N	Computer Science & Engineering	\N	\N	MED-CSE-2024-99	REG-2024-0099	\N	\N
44	admin_3077993d@medal.gov.in	$2b$12$u.x8yDbI1i7bSKESCZls8eFjFnbt7ZGLjkfUkoGWJg6V3hjTm0PCu	Master Administrator	\N	admin	t	t	2026-10-26 23:25:31.123867+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
45	citizen_3077993d@example.com	$2b$12$yFX5Gj.2M3sUueB0cQFrKObrHYyjlEjIbxk8GzOuqqD10oCatKFAq	Civic Citizen	\N	citizen	t	t	2026-10-26 23:25:31.123867+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
46	admin_a48b82e9@medal.gov.in	$2b$12$C4jv7CnUJQ9JxEfHUDdvnOlo.H2LNbAz/zGiut./hEqi43TAqLrm2	Master Administrator	\N	admin	t	t	2026-10-26 23:29:16.999056+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
47	citizen_a48b82e9@example.com	$2b$12$VCxl46GYkpWztDPfr64cuuKpH4IJXjtWrFfZnrbkNY9UPwf/tL8e6	Civic Citizen	\N	citizen	t	t	2026-10-26 23:29:16.999056+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
52	alice_bd9efcb4@medal.app	$2b$12$nAh4iGMbzR3U.NxIsia1o.cQnZrAzw9bms45SqIpREq.4xBeFw.GS	Alice Green	9841000001	citizen	f	t	2026-10-26 23:29:59.524242+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
53	bob_897f8438@medal.app	$2b$12$8MEC.ST5ZbUYp/0OLadi.eYksOe.VEoQMWNBcMiyjf4EUJ3wFs3Se	Bob Kumar	9841000002	citizen	f	t	2026-10-26 23:29:59.946965+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
54	citizen_a_e91247ef@example.com	$2b$12$0yJpgpq6fR/JoDO8Eui7Zu.B.2S3ozyrKLXfLQQ71pkLRF1iaMCzO	Citizen Alice	9111111111	citizen	f	t	2026-10-26 23:30:10.136288+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
55	citizen_b_e91247ef@example.com	$2b$12$DXoGhMC00p7N5c7Et4Jb4uRCklAr5qutdo0cz1muGIfFbPCMj7Lum	Citizen Bob	9222222222	citizen	f	t	2026-10-26 23:30:10.347257+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
56	reporter_fcbd3793@example.com	$2b$12$DRZKrFT7onhHkQfyimMEMOTkD0G6d.G/axYYBI1p/.80p4R8QJH7W	Reporter Citizen fcbd3793	9988776655	citizen	f	t	2026-10-26 23:31:04.15991+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
57	reporter_47c31666@example.com	$2b$12$3C5fP4Tp/sRKMfxO7uEDe.aqHCLaMzZ07ojAE7fssjzcGHbDplmNa	Reporter Citizen 47c31666	9988776655	citizen	f	t	2026-10-26 23:31:54.880305+05:30	\N	approved	\N	\N	\N	\N	\N	\N	\N	\N
22	mithi@medal.gov	$2b$12$4B7y43xDknTfszOKtyEYGuEyol.c4NxYOAwVTsNp.iRkEBANoai7C	Mithilesh	\N	citizen	t	t	2026-09-23 15:38:30.789398+05:30	https://res.cloudinary.com/uco2jihi/image/upload/v1793038554/medal/avatars/profiles/22/asset_c64c7714bcdf4de287f59aff310f171a.jpg	approved	\N	\N	\N	\N	\N	\N	\N	medal/avatars/profiles/22/asset_c64c7714bcdf4de287f59aff310f171a
\.


--
-- Name: authority_applications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.authority_applications_id_seq', 2, true);


--
-- Name: complaint_comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.complaint_comments_id_seq', 26, true);


--
-- Name: complaint_reposts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.complaint_reposts_id_seq', 9, true);


--
-- Name: complaint_upvotes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.complaint_upvotes_id_seq', 40, true);


--
-- Name: complaints_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.complaints_id_seq', 144, true);


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.password_reset_otps_id_seq', 1, false);


--
-- Name: student_certificates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_certificates_id_seq', 7, true);


--
-- Name: student_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_courses_id_seq', 1, false);


--
-- Name: student_enrollments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_enrollments_id_seq', 11, true);


--
-- Name: student_notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_notifications_id_seq', 14, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 57, true);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: authority_applications authority_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authority_applications
    ADD CONSTRAINT authority_applications_pkey PRIMARY KEY (id);


--
-- Name: complaint_comments complaint_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_comments
    ADD CONSTRAINT complaint_comments_pkey PRIMARY KEY (id);


--
-- Name: complaint_reposts complaint_reposts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_reposts
    ADD CONSTRAINT complaint_reposts_pkey PRIMARY KEY (id);


--
-- Name: complaint_upvotes complaint_upvotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_upvotes
    ADD CONSTRAINT complaint_upvotes_pkey PRIMARY KEY (id);


--
-- Name: complaints complaints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_pkey PRIMARY KEY (id);


--
-- Name: password_reset_otps password_reset_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps
    ADD CONSTRAINT password_reset_otps_pkey PRIMARY KEY (id);


--
-- Name: student_certificates student_certificates_certificate_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_certificates
    ADD CONSTRAINT student_certificates_certificate_no_key UNIQUE (certificate_no);


--
-- Name: student_certificates student_certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_certificates
    ADD CONSTRAINT student_certificates_pkey PRIMARY KEY (id);


--
-- Name: student_courses student_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_courses
    ADD CONSTRAINT student_courses_pkey PRIMARY KEY (id);


--
-- Name: student_enrollments student_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_enrollments
    ADD CONSTRAINT student_enrollments_pkey PRIMARY KEY (id);


--
-- Name: student_notifications student_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_notifications
    ADD CONSTRAINT student_notifications_pkey PRIMARY KEY (id);


--
-- Name: complaint_reposts uq_user_complaint_repost; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_reposts
    ADD CONSTRAINT uq_user_complaint_repost UNIQUE (user_id, complaint_id);


--
-- Name: complaint_upvotes uq_user_complaint_upvote; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_upvotes
    ADD CONSTRAINT uq_user_complaint_upvote UNIQUE (user_id, complaint_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_authority_applications_official_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_authority_applications_official_email ON public.authority_applications USING btree (official_email);


--
-- Name: ix_authority_applications_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_authority_applications_status ON public.authority_applications USING btree (status);


--
-- Name: ix_authority_applications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_authority_applications_user_id ON public.authority_applications USING btree (user_id);


--
-- Name: ix_complaint_comments_complaint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_comments_complaint_id ON public.complaint_comments USING btree (complaint_id);


--
-- Name: ix_complaint_comments_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_comments_id ON public.complaint_comments USING btree (id);


--
-- Name: ix_complaint_comments_parent_comment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_comments_parent_comment_id ON public.complaint_comments USING btree (parent_comment_id);


--
-- Name: ix_complaint_comments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_comments_user_id ON public.complaint_comments USING btree (user_id);


--
-- Name: ix_complaint_reposts_complaint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_reposts_complaint_id ON public.complaint_reposts USING btree (complaint_id);


--
-- Name: ix_complaint_reposts_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_reposts_id ON public.complaint_reposts USING btree (id);


--
-- Name: ix_complaint_reposts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_reposts_user_id ON public.complaint_reposts USING btree (user_id);


--
-- Name: ix_complaint_upvotes_complaint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_upvotes_complaint_id ON public.complaint_upvotes USING btree (complaint_id);


--
-- Name: ix_complaint_upvotes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_upvotes_id ON public.complaint_upvotes USING btree (id);


--
-- Name: ix_complaint_upvotes_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_upvotes_user_id ON public.complaint_upvotes USING btree (user_id);


--
-- Name: ix_complaints_citizen_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaints_citizen_id ON public.complaints USING btree (citizen_id);


--
-- Name: ix_password_reset_otps_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_password_reset_otps_email ON public.password_reset_otps USING btree (email);


--
-- Name: ix_password_reset_otps_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_password_reset_otps_id ON public.password_reset_otps USING btree (id);


--
-- Name: ix_password_reset_otps_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_password_reset_otps_user_id ON public.password_reset_otps USING btree (user_id);


--
-- Name: ix_student_certificates_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_certificates_id ON public.student_certificates USING btree (id);


--
-- Name: ix_student_certificates_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_certificates_user_id ON public.student_certificates USING btree (user_id);


--
-- Name: ix_student_courses_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_courses_id ON public.student_courses USING btree (id);


--
-- Name: ix_student_enrollments_course_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_enrollments_course_id ON public.student_enrollments USING btree (course_id);


--
-- Name: ix_student_enrollments_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_enrollments_id ON public.student_enrollments USING btree (id);


--
-- Name: ix_student_enrollments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_enrollments_user_id ON public.student_enrollments USING btree (user_id);


--
-- Name: ix_student_notifications_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_notifications_id ON public.student_notifications USING btree (id);


--
-- Name: ix_student_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_student_notifications_user_id ON public.student_notifications USING btree (user_id);


--
-- Name: ix_users_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_users_approval_status ON public.users USING btree (approval_status);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: authority_applications authority_applications_reviewed_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authority_applications
    ADD CONSTRAINT authority_applications_reviewed_by_id_fkey FOREIGN KEY (reviewed_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: authority_applications authority_applications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authority_applications
    ADD CONSTRAINT authority_applications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: complaint_comments complaint_comments_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_comments
    ADD CONSTRAINT complaint_comments_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- Name: complaint_comments complaint_comments_parent_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_comments
    ADD CONSTRAINT complaint_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.complaint_comments(id) ON DELETE CASCADE;


--
-- Name: complaint_comments complaint_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_comments
    ADD CONSTRAINT complaint_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: complaint_reposts complaint_reposts_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_reposts
    ADD CONSTRAINT complaint_reposts_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- Name: complaint_reposts complaint_reposts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_reposts
    ADD CONSTRAINT complaint_reposts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: complaint_upvotes complaint_upvotes_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_upvotes
    ADD CONSTRAINT complaint_upvotes_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- Name: complaint_upvotes complaint_upvotes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaint_upvotes
    ADD CONSTRAINT complaint_upvotes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: complaints complaints_citizen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_citizen_id_fkey FOREIGN KEY (citizen_id) REFERENCES public.users(id);


--
-- Name: password_reset_otps password_reset_otps_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps
    ADD CONSTRAINT password_reset_otps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: student_certificates student_certificates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_certificates
    ADD CONSTRAINT student_certificates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: student_enrollments student_enrollments_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_enrollments
    ADD CONSTRAINT student_enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.student_courses(id) ON DELETE CASCADE;


--
-- Name: student_enrollments student_enrollments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_enrollments
    ADD CONSTRAINT student_enrollments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: student_notifications student_notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_notifications
    ADD CONSTRAINT student_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 4DpULWCqlZr00QtTZr3MDQdlwIV06L7RmjGNWsLJHOEuufUFbBISasaBROo7IYQ

