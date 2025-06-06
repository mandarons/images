-- Sample initialization script for the application database
-- This file will be executed during PostgreSQL initialization

-- Create a sample table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample data
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com')
ON CONFLICT (username) DO NOTHING;

-- Create an index for better performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Grant permissions to the application user
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO admin;
GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO admin;

-- Display confirmation
SELECT 'Database initialization completed successfully' as status;
