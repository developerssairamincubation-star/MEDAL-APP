-- ====================================================================
-- MEdAL (Municipal Evidence & Digital Action Logging)
-- Sample Seed Data for Local Development & Testing
-- Pre-hashed passwords for all seed accounts: "Password123!"
-- ====================================================================

-- 1. SEED USERS
-- Password for all accounts: "Password123!" ($2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi)
INSERT INTO users (id, email, password_hash, full_name, phone, role, is_verified, is_active, created_at, updated_at)
VALUES
(
    1,
    'admin@medal.gov.in',
    '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Municipal Commissioner',
    '+91 9876543210',
    'admin',
    TRUE,
    TRUE,
    CURRENT_TIMESTAMP - INTERVAL '30 days',
    CURRENT_TIMESTAMP - INTERVAL '30 days'
),
(
    2,
    'ward.officer@medal.gov.in',
    '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Anitha Rajshekar (Ward 14 Officer)',
    '+91 9876543211',
    'official',
    TRUE,
    TRUE,
    CURRENT_TIMESTAMP - INTERVAL '25 days',
    CURRENT_TIMESTAMP - INTERVAL '25 days'
),
(
    3,
    'james.doe@example.com',
    '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'James Doe',
    '+91 9876543212',
    'citizen',
    TRUE,
    TRUE,
    CURRENT_TIMESTAMP - INTERVAL '20 days',
    CURRENT_TIMESTAMP - INTERVAL '20 days'
),
(
    4,
    'maria.lopez@example.com',
    '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Maria Lopez',
    '+91 9876543213',
    'citizen',
    TRUE,
    TRUE,
    CURRENT_TIMESTAMP - INTERVAL '15 days',
    CURRENT_TIMESTAMP - INTERVAL '15 days'
),
(
    5,
    'olivia.iver@example.com',
    '$2b$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Olivia Iver',
    '+91 9876543214',
    'citizen',
    TRUE,
    TRUE,
    CURRENT_TIMESTAMP - INTERVAL '10 days',
    CURRENT_TIMESTAMP - INTERVAL '10 days'
)
ON CONFLICT (id) DO NOTHING;

-- Reset users sequence
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM users));


-- 2. SEED COMPLAINTS
INSERT INTO complaints (id, title, description, category, status, location, image_url, sdg_alignment, impact_level, equity_classification, citizen_id, created_at, updated_at)
VALUES
(
    101,
    'Critical Canal Junction Waste Blockage',
    'Massive solid waste accumulation causing canal overflow and severe foul smell during monsoon rains. High public health hazard for adjacent residential colony.',
    'garbage',
    'in_progress',
    'Canal Junction, Bharathiyar Street, Ward 14',
    'http://localhost:9000/medal-evidence/reports/sample_waste_canal.jpg',
    'SDG 6: Clean Water and Sanitation',
    'High',
    'Vulnerable Low-Income Neighborhood',
    3,
    CURRENT_TIMESTAMP - INTERVAL '2 hours',
    CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
(
    102,
    'Streetlight Cluster Outage on 5th Cross Road',
    'Five continuous streetlights non-functional causing complete blackout on pedestrian corridor connecting school to bus terminal.',
    'streetlight',
    'resolved',
    '5th Cross Road, Sector 3',
    'http://localhost:9000/medal-evidence/reports/sample_streetlight.jpg',
    'SDG 11: Sustainable Cities and Communities',
    'Medium',
    'School / Hospital Vicinity',
    4,
    CURRENT_TIMESTAMP - INTERVAL '1 day',
    CURRENT_TIMESTAMP - INTERVAL '4 hours'
),
(
    103,
    'Deep Pothole Crater near General Hospital Gate 2',
    'Large deep crater developed in the middle lane following underground pipe repair. Causing severe traffic congestion and near accidents for ambulances.',
    'road',
    'under_review',
    'Opposite Hospital Gate 2, Ring Road',
    'http://localhost:9000/medal-evidence/reports/sample_pothole.jpg',
    'SDG 9: Industry, Innovation and Infrastructure',
    'Critical',
    'Emergency Route / Hospital Zone',
    5,
    CURRENT_TIMESTAMP - INTERVAL '3 hours',
    CURRENT_TIMESTAMP - INTERVAL '3 hours'
),
(
    104,
    'Drinking Water Pipeline Burst near Community Park',
    'Clean municipal potable water gushing on the road since morning, wasting thousands of liters while surrounding homes experience zero water pressure.',
    'water',
    'submitted',
    'Near Children Community Park, Ward 11',
    'http://localhost:9000/medal-evidence/reports/sample_water_leak.jpg',
    'SDG 6: Clean Water and Sanitation',
    'High',
    'Public Park / Community Space',
    3,
    CURRENT_TIMESTAMP - INTERVAL '30 minutes',
    CURRENT_TIMESTAMP - INTERVAL '30 minutes'
)
ON CONFLICT (id) DO NOTHING;

-- Reset complaints sequence
SELECT setval('complaints_id_seq', (SELECT COALESCE(MAX(id), 1) FROM complaints));


-- 3. SEED UPVOTES
INSERT INTO complaint_upvotes (id, complaint_id, user_id, created_at)
VALUES
(1, 101, 4, CURRENT_TIMESTAMP - INTERVAL '90 minutes'),
(2, 101, 5, CURRENT_TIMESTAMP - INTERVAL '45 minutes'),
(3, 103, 3, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
(4, 103, 4, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
(5, 104, 5, CURRENT_TIMESTAMP - INTERVAL '15 minutes')
ON CONFLICT (user_id, complaint_id) DO NOTHING;

-- Reset complaint_upvotes sequence
SELECT setval('complaint_upvotes_id_seq', (SELECT COALESCE(MAX(id), 1) FROM complaint_upvotes));
