-- ====================================================================
-- MEdAL (Municipal Evidence & Digital Action Logging)
-- Relational Database Schema Definition (PostgreSQL 14+)
-- ====================================================================

-- 1. USERS TABLE
-- Stores citizen, municipal official, and administrator credentials & profiles
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(50),
    role VARCHAR(50) NOT NULL DEFAULT 'citizen' CHECK (role IN ('citizen', 'official', 'admin')),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
CREATE INDEX IF NOT EXISTS ix_users_role ON users (role);


-- 2. COMPLAINTS TABLE
-- Stores civic reports, metadata, photo evidence URLs (Cloudinary / Object Storage), and SDG tags
CREATE TABLE IF NOT EXISTS complaints (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'in_progress', 'resolved', 'rejected')),
    location VARCHAR(255) NOT NULL,
    image_url VARCHAR(500),
    image_public_id VARCHAR(255),
    sdg_alignment VARCHAR(255),
    impact_level VARCHAR(100),
    equity_classification VARCHAR(255),
    citizen_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_complaints_id ON complaints (id);
CREATE INDEX IF NOT EXISTS ix_complaints_citizen_id ON complaints (citizen_id);
CREATE INDEX IF NOT EXISTS ix_complaints_category ON complaints (category);
CREATE INDEX IF NOT EXISTS ix_complaints_status ON complaints (status);
CREATE INDEX IF NOT EXISTS ix_complaints_created_at ON complaints (created_at DESC);


-- 3. COMPLAINT UPVOTES TABLE
-- Stores citizen endorsements/upvotes to prioritize severe civic issues
CREATE TABLE IF NOT EXISTS complaint_upvotes (
    id SERIAL PRIMARY KEY,
    complaint_id INTEGER NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_complaint_upvote UNIQUE (user_id, complaint_id)
);

CREATE INDEX IF NOT EXISTS ix_complaint_upvotes_id ON complaint_upvotes (id);
CREATE INDEX IF NOT EXISTS ix_complaint_upvotes_complaint_id ON complaint_upvotes (complaint_id);
CREATE INDEX IF NOT EXISTS ix_complaint_upvotes_user_id ON complaint_upvotes (user_id);
