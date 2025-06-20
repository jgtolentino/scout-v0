-- =============================================
-- Scout Analytics Dashboard - Comprehensive Schema
-- Version: 1.0.0
-- Date: 2024-12-20
-- =============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- =============================================
-- CORE TABLES
-- =============================================

-- Brands table
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    category VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(255),
    country_origin VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products table
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
    sku VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    unit_size VARCHAR(50),
    unit_cost DECIMAL(10,2) NOT NULL,
    retail_price DECIMAL(10,2) NOT NULL,
    margin_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN unit_cost > 0 THEN ((retail_price - unit_cost) / unit_cost) * 100
            ELSE 0
        END
    ) STORED,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customers table
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_code VARCHAR(50) UNIQUE,
    gender VARCHAR(10) CHECK (gender IN ('Male', 'Female', 'Other')),
    age_group VARCHAR(20) CHECK (age_group IN ('18-25', '26-35', '36-45', '46-55', '56-65', '65+')),
    location_region VARCHAR(100),
    location_province VARCHAR(100),
    location_city VARCHAR(100),
    location_barangay VARCHAR(100),
    income_bracket VARCHAR(50),
    loyalty_tier VARCHAR(20) DEFAULT 'Bronze',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Stores table
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'Grocery', 'Convenience', 'Supermarket', etc.
    region VARCHAR(100) NOT NULL,
    province VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    barangay VARCHAR(100),
    address TEXT,
    coordinates POINT,
    store_size VARCHAR(20), -- 'Small', 'Medium', 'Large'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transactions table
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_code VARCHAR(100) NOT NULL UNIQUE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    total_amount DECIMAL(12,2) NOT NULL,
    total_items INTEGER NOT NULL DEFAULT 0,
    payment_method VARCHAR(50),
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    is_weekend BOOLEAN GENERATED ALWAYS AS (
        EXTRACT(DOW FROM transaction_date) IN (0, 6)
    ) STORED,
    hour_of_day INTEGER GENERATED ALWAYS AS (
        EXTRACT(HOUR FROM transaction_date)
    ) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transaction Items table
CREATE TABLE transaction_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Substitutions table
CREATE TABLE substitutions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    original_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    substitute_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    reason VARCHAR(255),
    customer_satisfaction_score INTEGER CHECK (customer_satisfaction_score BETWEEN 1 AND 5),
    was_accepted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device Health table
CREATE TABLE device_health (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id VARCHAR(100) NOT NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('online', 'offline', 'maintenance', 'error')),
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_usage DECIMAL(5,2),
    network_latency INTEGER,
    last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    error_count INTEGER DEFAULT 0,
    uptime_hours DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Devices table
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id VARCHAR(100) NOT NULL UNIQUE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    device_type VARCHAR(50) NOT NULL,
    model VARCHAR(100),
    firmware_version VARCHAR(50),
    installation_date DATE,
    last_maintenance DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Edge Logs table
CREATE TABLE edge_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id VARCHAR(100) NOT NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    log_level VARCHAR(20) NOT NULL CHECK (log_level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
    message TEXT NOT NULL,
    component VARCHAR(100),
    error_code VARCHAR(50),
    metadata JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Request Behaviors table
CREATE TABLE request_behaviors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    request_type VARCHAR(100) NOT NULL,
    request_category VARCHAR(100),
    request_details JSONB,
    response_time_ms INTEGER,
    was_successful BOOLEAN DEFAULT true,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer Requests table
CREATE TABLE customer_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    request_type VARCHAR(100) NOT NULL,
    product_category VARCHAR(100),
    specific_product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    request_description TEXT,
    urgency_level INTEGER CHECK (urgency_level BETWEEN 1 AND 5),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'fulfilled', 'cancelled')),
    fulfilled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Transaction-related indexes
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_store_date ON transactions(store_id, transaction_date);
CREATE INDEX idx_transactions_customer ON transactions(customer_id);
CREATE INDEX idx_transactions_weekend ON transactions(is_weekend);
CREATE INDEX idx_transactions_hour ON transactions(hour_of_day);

-- Transaction items indexes
CREATE INDEX idx_transaction_items_transaction ON transaction_items(transaction_id);
CREATE INDEX idx_transaction_items_product ON transaction_items(product_id);

-- Product-related indexes
CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_category ON products(category, subcategory);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_active ON products(is_active);

-- Customer-related indexes
CREATE INDEX idx_customers_demographics ON customers(gender, age_group);
CREATE INDEX idx_customers_location ON customers(location_region, location_province, location_city);
CREATE INDEX idx_customers_active ON customers(is_active);

-- Store-related indexes
CREATE INDEX idx_stores_location ON stores(region, province, city);
CREATE INDEX idx_stores_type ON stores(type);
CREATE INDEX idx_stores_active ON stores(is_active);

-- Device and logging indexes
CREATE INDEX idx_device_health_device_store ON device_health(device_id, store_id);
CREATE INDEX idx_device_health_status ON device_health(status);
CREATE INDEX idx_edge_logs_device_timestamp ON edge_logs(device_id, timestamp);
CREATE INDEX idx_edge_logs_level ON edge_logs(log_level);

-- Behavioral indexes
CREATE INDEX idx_request_behaviors_customer ON request_behaviors(customer_id);
CREATE INDEX idx_request_behaviors_store_timestamp ON request_behaviors(store_id, timestamp);
CREATE INDEX idx_customer_requests_status ON customer_requests(status);
CREATE INDEX idx_customer_requests_type ON customer_requests(request_type);

-- =============================================
-- AUDIT TABLE
-- =============================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id UUID NOT NULL,
    old_values JSONB,
    new_values JSONB,
    user_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_table_operation ON audit_logs(table_name, operation);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);

-- =============================================
-- UPDATE TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update triggers to relevant tables
CREATE TRIGGER update_brands_updated_at BEFORE UPDATE ON brands
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stores_updated_at BEFORE UPDATE ON stores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customer_requests_updated_at BEFORE UPDATE ON customer_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- AUDIT TRIGGERS
-- =============================================

-- Generic audit function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_values)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.id, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, operation, record_id, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to all main tables
CREATE TRIGGER audit_brands AFTER INSERT OR UPDATE OR DELETE ON brands
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_products AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_customers AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_stores AFTER INSERT OR UPDATE OR DELETE ON stores
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_transactions AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_transaction_items AFTER INSERT OR UPDATE OR DELETE ON transaction_items
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- =============================================
-- VALIDATION CONSTRAINTS
-- =============================================

-- Additional constraints for data integrity
ALTER TABLE transactions ADD CONSTRAINT chk_transaction_amount 
    CHECK (total_amount >= 0 AND total_items >= 0);

ALTER TABLE transaction_items ADD CONSTRAINT chk_item_price 
    CHECK (unit_price >= 0 AND quantity > 0);

ALTER TABLE products ADD CONSTRAINT chk_product_pricing 
    CHECK (unit_cost >= 0 AND retail_price >= 0);

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE brands IS 'Master data for product brands and manufacturers';
COMMENT ON TABLE products IS 'Product catalog with SKUs, pricing, and categorization';
COMMENT ON TABLE customers IS 'Customer demographics and segmentation data';
COMMENT ON TABLE stores IS 'Store locations and operational details';
COMMENT ON TABLE transactions IS 'Sales transaction headers with computed fields';
COMMENT ON TABLE transaction_items IS 'Individual line items within transactions';
COMMENT ON TABLE substitutions IS 'Product substitution tracking and acceptance rates';
COMMENT ON TABLE device_health IS 'Real-time device monitoring and health metrics';
COMMENT ON TABLE devices IS 'Device inventory and configuration management';
COMMENT ON TABLE edge_logs IS 'Application and system logs from edge devices';
COMMENT ON TABLE request_behaviors IS 'Customer interaction and request patterns';
COMMENT ON TABLE customer_requests IS 'Specific customer requests and fulfillment tracking';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all data changes';