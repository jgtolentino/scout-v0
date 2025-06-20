-- =============================================
-- Scout Analytics Dashboard - RLS Policies
-- Version: 1.0.0
-- Date: 2024-12-20
-- =============================================

-- Enable RLS on all tables
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE substitutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE edge_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_behaviors ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- =============================================
-- USER ROLES AND AUTHENTICATION
-- =============================================

-- Create custom roles
DO $$
BEGIN
    -- Super Admin role (full access)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'scout_super_admin') THEN
        CREATE ROLE scout_super_admin;
    END IF;
    
    -- Regional Manager role (region-specific access)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'scout_regional_manager') THEN
        CREATE ROLE scout_regional_manager;
    END IF;
    
    -- Store Manager role (store-specific access)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'scout_store_manager') THEN
        CREATE ROLE scout_store_manager;
    END IF;
    
    -- Analyst role (read-only access)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'scout_analyst') THEN
        CREATE ROLE scout_analyst;
    END IF;
    
    -- API Service role (application access)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'scout_api_service') THEN
        CREATE ROLE scout_api_service;
    END IF;
END
$$;

-- =============================================
-- USER MANAGEMENT TABLE
-- =============================================

CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- This will map to Supabase auth.users.id
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('super_admin', 'regional_manager', 'store_manager', 'analyst', 'api_service')),
    region VARCHAR(100), -- For regional managers
    store_ids UUID[], -- For store managers (array of store IDs)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable RLS on user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- =============================================
-- HELPER FUNCTIONS FOR RLS
-- =============================================

-- Function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role 
    FROM user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true;
    
    RETURN COALESCE(user_role, 'anonymous');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's allowed regions
CREATE OR REPLACE FUNCTION get_user_regions()
RETURNS TEXT[] AS $$
DECLARE
    user_regions TEXT[];
BEGIN
    SELECT ARRAY[region] INTO user_regions 
    FROM user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true
    AND region IS NOT NULL;
    
    RETURN COALESCE(user_regions, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's allowed store IDs
CREATE OR REPLACE FUNCTION get_user_store_ids()
RETURNS UUID[] AS $$
DECLARE
    user_store_ids UUID[];
BEGIN
    SELECT store_ids INTO user_store_ids 
    FROM user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true
    AND store_ids IS NOT NULL;
    
    RETURN COALESCE(user_store_ids, ARRAY[]::UUID[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN get_user_role() = 'super_admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- BRANDS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on brands" ON brands
    FOR ALL USING (is_super_admin());

-- Others can only read
CREATE POLICY "Read access on brands" ON brands
    FOR SELECT USING (
        get_user_role() IN ('regional_manager', 'store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- PRODUCTS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on products" ON products
    FOR ALL USING (is_super_admin());

-- Others can only read
CREATE POLICY "Read access on products" ON products
    FOR SELECT USING (
        get_user_role() IN ('regional_manager', 'store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- STORES TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on stores" ON stores
    FOR ALL USING (is_super_admin());

-- Regional managers can access stores in their region
CREATE POLICY "Regional manager access on stores" ON stores
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND region = ANY(get_user_regions())
    );

-- Store managers can access their specific stores
CREATE POLICY "Store manager access on stores" ON stores
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND id = ANY(get_user_store_ids())
    );

-- Analysts can read all stores
CREATE POLICY "Analyst read access on stores" ON stores
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- CUSTOMERS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on customers" ON customers
    FOR ALL USING (is_super_admin());

-- Regional managers can access customers in their region
CREATE POLICY "Regional manager access on customers" ON customers
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND location_region = ANY(get_user_regions())
    );

-- Store managers and analysts can read all customers (for analytics)
CREATE POLICY "Store manager and analyst read access on customers" ON customers
    FOR SELECT USING (
        get_user_role() IN ('store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- TRANSACTIONS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on transactions" ON transactions
    FOR ALL USING (is_super_admin());

-- Regional managers can access transactions from stores in their region
CREATE POLICY "Regional manager access on transactions" ON transactions
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

-- Store managers can access transactions from their stores
CREATE POLICY "Store manager access on transactions" ON transactions
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

-- Analysts and API service can read all transactions
CREATE POLICY "Analyst and API read access on transactions" ON transactions
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- TRANSACTION ITEMS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on transaction_items" ON transaction_items
    FOR ALL USING (is_super_admin());

-- Regional managers can access transaction items from their region
CREATE POLICY "Regional manager access on transaction_items" ON transaction_items
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM transactions t
            JOIN stores s ON t.store_id = s.id
            WHERE t.id = transaction_id 
            AND s.region = ANY(get_user_regions())
        )
    );

-- Store managers can access transaction items from their stores
CREATE POLICY "Store manager access on transaction_items" ON transaction_items
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND EXISTS (
            SELECT 1 FROM transactions t
            WHERE t.id = transaction_id 
            AND t.store_id = ANY(get_user_store_ids())
        )
    );

-- Analysts and API service can read all transaction items
CREATE POLICY "Analyst and API read access on transaction_items" ON transaction_items
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- SUBSTITUTIONS TABLE RLS POLICIES
-- =============================================

-- Similar pattern for substitutions
CREATE POLICY "Super admin full access on substitutions" ON substitutions
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on substitutions" ON substitutions
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM transactions t
            JOIN stores s ON t.store_id = s.id
            WHERE t.id = transaction_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on substitutions" ON substitutions
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND EXISTS (
            SELECT 1 FROM transactions t
            WHERE t.id = transaction_id 
            AND t.store_id = ANY(get_user_store_ids())
        )
    );

CREATE POLICY "Analyst and API read access on substitutions" ON substitutions
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- DEVICE-RELATED TABLE RLS POLICIES
-- =============================================

-- Device Health policies
CREATE POLICY "Super admin full access on device_health" ON device_health
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on device_health" ON device_health
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on device_health" ON device_health
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

CREATE POLICY "API service access on device_health" ON device_health
    FOR ALL USING (get_user_role() = 'api_service');

-- Devices policies
CREATE POLICY "Super admin full access on devices" ON devices
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on devices" ON devices
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on devices" ON devices
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

CREATE POLICY "API service access on devices" ON devices
    FOR ALL USING (get_user_role() = 'api_service');

-- Edge Logs policies
CREATE POLICY "Super admin full access on edge_logs" ON edge_logs
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on edge_logs" ON edge_logs
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on edge_logs" ON edge_logs
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

CREATE POLICY "API service access on edge_logs" ON edge_logs
    FOR ALL USING (get_user_role() = 'api_service');

-- =============================================
-- BEHAVIORAL DATA RLS POLICIES
-- =============================================

-- Request Behaviors policies
CREATE POLICY "Super admin full access on request_behaviors" ON request_behaviors
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on request_behaviors" ON request_behaviors
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on request_behaviors" ON request_behaviors
    FOR SELECT USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

CREATE POLICY "Analyst and API read access on request_behaviors" ON request_behaviors
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- Customer Requests policies
CREATE POLICY "Super admin full access on customer_requests" ON customer_requests
    FOR ALL USING (is_super_admin());

CREATE POLICY "Regional manager access on customer_requests" ON customer_requests
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(get_user_regions())
        )
    );

CREATE POLICY "Store manager access on customer_requests" ON customer_requests
    FOR ALL USING (
        get_user_role() = 'store_manager' 
        AND store_id = ANY(get_user_store_ids())
    );

CREATE POLICY "Analyst read access on customer_requests" ON customer_requests
    FOR SELECT USING (
        get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- USER ROLES TABLE RLS POLICIES
-- =============================================

-- Super admin can manage all user roles
CREATE POLICY "Super admin full access on user_roles" ON user_roles
    FOR ALL USING (is_super_admin());

-- Users can read their own role information
CREATE POLICY "Users can read own role" ON user_roles
    FOR SELECT USING (user_id = auth.uid());

-- =============================================
-- AUDIT LOGS RLS POLICIES
-- =============================================

-- Super admin can read all audit logs
CREATE POLICY "Super admin read access on audit_logs" ON audit_logs
    FOR SELECT USING (is_super_admin());

-- Regional managers can read audit logs for their region (where applicable)
CREATE POLICY "Regional manager limited audit access" ON audit_logs
    FOR SELECT USING (
        get_user_role() = 'regional_manager' 
        AND table_name IN ('transactions', 'transaction_items', 'stores', 'devices', 'device_health')
    );

-- =============================================
-- GRANTS AND PERMISSIONS
-- =============================================

-- Grant necessary permissions to roles
GRANT USAGE ON SCHEMA public TO scout_super_admin, scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO scout_analyst;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO scout_api_service;
GRANT ALL ON ALL TABLES IN SCHEMA public TO scout_super_admin;

-- Grant access to views
GRANT SELECT ON vw_transaction_trends TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON vw_product_mix TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON vw_substitutions TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON vw_consumer_behavior TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON vw_consumer_profile TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;

-- Grant access to materialized views
GRANT SELECT ON mv_daily_transaction_summary TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON mv_product_performance_summary TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_user_role() TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_user_regions() TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_user_store_ids() TO PUBLIC;
GRANT EXECUTE ON FUNCTION is_super_admin() TO PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_analytical_views() TO scout_super_admin, scout_api_service;

-- =============================================
-- DEFAULT USER SETUP
-- =============================================

-- Create a function to setup default admin user (to be called after first deployment)
CREATE OR REPLACE FUNCTION setup_default_admin(admin_email TEXT)
RETURNS void AS $$
BEGIN
    -- This function should be called manually after deployment
    -- with the email of the first admin user
    INSERT INTO user_roles (user_id, email, role, is_active)
    SELECT 
        id, 
        admin_email, 
        'super_admin', 
        true
    FROM auth.users 
    WHERE email = admin_email
    ON CONFLICT (user_id) DO UPDATE SET
        role = 'super_admin',
        is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE user_roles IS 'User role management with region and store-level access control';
COMMENT ON FUNCTION get_user_role() IS 'Returns the current user role for RLS policies';
COMMENT ON FUNCTION get_user_regions() IS 'Returns allowed regions for regional managers';
COMMENT ON FUNCTION get_user_store_ids() IS 'Returns allowed store IDs for store managers';
COMMENT ON FUNCTION setup_default_admin(TEXT) IS 'Sets up the first super admin user - call manually after deployment';