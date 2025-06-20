-- =============================================
-- Scout Analytics Dashboard - Canonical Base Schema
-- Migration: 001_init_schema.sql
-- Description: Core tables with audit columns only
-- =============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- CORE TABLES WITH AUDIT COLUMNS
-- =============================================

-- Brands table
CREATE TABLE public.brands (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  category text NOT NULL,
  manufacturer text,
  country_origin text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT brands_pkey PRIMARY KEY (id)
);

-- Customers table
CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_code text UNIQUE,
  age_group text NOT NULL CHECK (age_group = ANY (ARRAY['18-25'::text, '26-35'::text, '36-45'::text, '46-55'::text, '56-65'::text, '65+'::text])),
  gender text NOT NULL CHECK (gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Other'::text])),
  location_region text,
  location_province text,
  location_city text,
  location_barangay text,
  income_bracket text CHECK (income_bracket = ANY (ARRAY['Low'::text, 'Middle'::text, 'Upper Middle'::text, 'High'::text])),
  loyalty_tier text DEFAULT 'Bronze'::text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (id)
);

-- Products table
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL,
  sku text NOT NULL UNIQUE,
  name text NOT NULL,
  category text NOT NULL,
  subcategory text,
  unit_size text,
  unit_cost numeric(10,2) NOT NULL,
  retail_price numeric(10,2) NOT NULL,
  margin_percentage numeric(5,2) GENERATED ALWAYS AS (
    CASE 
      WHEN unit_cost > 0 THEN ((retail_price - unit_cost) / unit_cost) * 100
      ELSE 0
    END
  ) STORED,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON DELETE CASCADE
);

-- Stores table
CREATE TABLE public.stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_code text NOT NULL UNIQUE,
  name text NOT NULL,
  type text NOT NULL,
  region text NOT NULL,
  province text NOT NULL,
  city text NOT NULL,
  barangay text,
  address text,
  coordinates point,
  store_size text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT stores_pkey PRIMARY KEY (id)
);

-- Transactions table
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_code text NOT NULL UNIQUE,
  customer_id uuid,
  store_id uuid NOT NULL,
  transaction_date timestamp with time zone NOT NULL DEFAULT now(),
  total_amount numeric(12,2) NOT NULL,
  total_items integer NOT NULL DEFAULT 0,
  payment_method text,
  discount_amount numeric(10,2) DEFAULT 0,
  tax_amount numeric(10,2) DEFAULT 0,
  is_weekend boolean GENERATED ALWAYS AS (
    EXTRACT(DOW FROM transaction_date) IN (0, 6)
  ) STORED,
  hour_of_day integer GENERATED ALWAYS AS (
    EXTRACT(HOUR FROM transaction_date)
  ) STORED,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL,
  CONSTRAINT transactions_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE
);

-- Transaction Items table
CREATE TABLE public.transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL,
  total_price numeric(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  discount_amount numeric(10,2) DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE,
  CONSTRAINT transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

-- Substitutions table
CREATE TABLE public.substitutions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  original_product_id uuid NOT NULL,
  substitute_product_id uuid NOT NULL,
  reason text,
  customer_satisfaction_score integer CHECK (customer_satisfaction_score BETWEEN 1 AND 5),
  was_accepted boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT substitutions_pkey PRIMARY KEY (id),
  CONSTRAINT substitutions_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE,
  CONSTRAINT substitutions_original_product_id_fkey FOREIGN KEY (original_product_id) REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT substitutions_substitute_product_id_fkey FOREIGN KEY (substitute_product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

-- Device Health table
CREATE TABLE public.device_health (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  device_id text NOT NULL,
  store_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('online', 'offline', 'maintenance', 'error')),
  cpu_usage numeric(5,2),
  memory_usage numeric(5,2),
  disk_usage numeric(5,2),
  network_latency integer,
  last_heartbeat timestamp with time zone DEFAULT now(),
  error_count integer DEFAULT 0,
  uptime_hours numeric(10,2),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT device_health_pkey PRIMARY KEY (id),
  CONSTRAINT device_health_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE
);

-- Devices table
CREATE TABLE public.devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  device_id text NOT NULL UNIQUE,
  store_id uuid NOT NULL,
  device_type text NOT NULL,
  model text,
  firmware_version text,
  installation_date date,
  last_maintenance date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT devices_pkey PRIMARY KEY (id),
  CONSTRAINT devices_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE
);

-- Edge Logs table
CREATE TABLE public.edge_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  device_id text NOT NULL,
  store_id uuid NOT NULL,
  log_level text NOT NULL CHECK (log_level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
  message text NOT NULL,
  component text,
  error_code text,
  metadata jsonb,
  timestamp timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT edge_logs_pkey PRIMARY KEY (id),
  CONSTRAINT edge_logs_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE
);

-- Request Behaviors table
CREATE TABLE public.request_behaviors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  store_id uuid NOT NULL,
  request_type text NOT NULL,
  request_category text,
  request_details jsonb,
  response_time_ms integer,
  was_successful boolean DEFAULT true,
  timestamp timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT request_behaviors_pkey PRIMARY KEY (id),
  CONSTRAINT request_behaviors_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL,
  CONSTRAINT request_behaviors_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE
);

-- Customer Requests table
CREATE TABLE public.customer_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  store_id uuid NOT NULL,
  request_type text NOT NULL,
  product_category text,
  specific_product_id uuid,
  request_description text,
  urgency_level integer CHECK (urgency_level BETWEEN 1 AND 5),
  status text DEFAULT 'pending'::text CHECK (status IN ('pending', 'processing', 'fulfilled', 'cancelled')),
  fulfilled_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT customer_requests_pkey PRIMARY KEY (id),
  CONSTRAINT customer_requests_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL,
  CONSTRAINT customer_requests_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE,
  CONSTRAINT customer_requests_specific_product_id_fkey FOREIGN KEY (specific_product_id) REFERENCES public.products(id) ON DELETE SET NULL
);

-- =============================================
-- BASIC INDEXES FOR PERFORMANCE
-- =============================================

-- Transaction-related indexes
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date);
CREATE INDEX idx_transactions_store_date ON public.transactions(store_id, transaction_date);
CREATE INDEX idx_transactions_customer ON public.transactions(customer_id);
CREATE INDEX idx_transactions_weekend ON public.transactions(is_weekend);
CREATE INDEX idx_transactions_hour ON public.transactions(hour_of_day);

-- Transaction items indexes
CREATE INDEX idx_transaction_items_transaction ON public.transaction_items(transaction_id);
CREATE INDEX idx_transaction_items_product ON public.transaction_items(product_id);

-- Product-related indexes
CREATE INDEX idx_products_brand ON public.products(brand_id);
CREATE INDEX idx_products_category ON public.products(category, subcategory);
CREATE INDEX idx_products_sku ON public.products(sku);
CREATE INDEX idx_products_active ON public.products(is_active);

-- Customer-related indexes
CREATE INDEX idx_customers_demographics ON public.customers(gender, age_group);
CREATE INDEX idx_customers_location ON public.customers(location_region, location_province, location_city);
CREATE INDEX idx_customers_active ON public.customers(is_active);

-- Store-related indexes
CREATE INDEX idx_stores_location ON public.stores(region, province, city);
CREATE INDEX idx_stores_type ON public.stores(type);
CREATE INDEX idx_stores_active ON public.stores(is_active);

-- Device and logging indexes
CREATE INDEX idx_device_health_device_store ON public.device_health(device_id, store_id);
CREATE INDEX idx_device_health_status ON public.device_health(status);
CREATE INDEX idx_edge_logs_device_timestamp ON public.edge_logs(device_id, timestamp);
CREATE INDEX idx_edge_logs_level ON public.edge_logs(log_level);

-- Behavioral indexes
CREATE INDEX idx_request_behaviors_customer ON public.request_behaviors(customer_id);
CREATE INDEX idx_request_behaviors_store_timestamp ON public.request_behaviors(store_id, timestamp);
CREATE INDEX idx_customer_requests_status ON public.customer_requests(status);
CREATE INDEX idx_customer_requests_type ON public.customer_requests(request_type);

-- =============================================
-- VALIDATION CONSTRAINTS
-- =============================================

-- Additional constraints for data integrity
ALTER TABLE public.transactions ADD CONSTRAINT chk_transaction_amount 
    CHECK (total_amount >= 0 AND total_items >= 0);

ALTER TABLE public.transaction_items ADD CONSTRAINT chk_item_price 
    CHECK (unit_price >= 0 AND quantity > 0);

ALTER TABLE public.products ADD CONSTRAINT chk_product_pricing 
    CHECK (unit_cost >= 0 AND retail_price >= 0);

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE public.brands IS 'Master data for product brands and manufacturers';
COMMENT ON TABLE public.products IS 'Product catalog with SKUs, pricing, and categorization';
COMMENT ON TABLE public.customers IS 'Customer demographics and segmentation data';
COMMENT ON TABLE public.stores IS 'Store locations and operational details';
COMMENT ON TABLE public.transactions IS 'Sales transaction headers with computed fields';
COMMENT ON TABLE public.transaction_items IS 'Individual line items within transactions';
COMMENT ON TABLE public.substitutions IS 'Product substitution tracking and acceptance rates';
COMMENT ON TABLE public.device_health IS 'Real-time device monitoring and health metrics';
COMMENT ON TABLE public.devices IS 'Device inventory and configuration management';
COMMENT ON TABLE public.edge_logs IS 'Application and system logs from edge devices';
COMMENT ON TABLE public.request_behaviors IS 'Customer interaction and request patterns';
COMMENT ON TABLE public.customer_requests IS 'Specific customer requests and fulfillment tracking';-- =============================================
-- Scout Analytics Dashboard - RLS Policies
-- Migration: 002_rls_policies.sql
-- Description: Row-level security, roles, and permissions
-- =============================================

-- Enable RLS on all tables
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.substitutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_behaviors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_requests ENABLE ROW LEVEL SECURITY;

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

CREATE TABLE public.user_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL, -- This will map to Supabase auth.users.id
    email text NOT NULL,
    role text NOT NULL CHECK (role IN ('super_admin', 'regional_manager', 'store_manager', 'analyst', 'api_service')),
    region text, -- For regional managers
    store_ids uuid[], -- For store managers (array of store IDs)
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    UNIQUE(user_id)
);

-- Enable RLS on user_roles
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- =============================================
-- HELPER FUNCTIONS FOR RLS
-- =============================================

-- Function to get current user's role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text AS $$
DECLARE
    user_role text;
BEGIN
    SELECT role INTO user_role 
    FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true;
    
    RETURN COALESCE(user_role, 'anonymous');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's allowed regions
CREATE OR REPLACE FUNCTION public.get_user_regions()
RETURNS text[] AS $$
DECLARE
    user_regions text[];
BEGIN
    SELECT ARRAY[region] INTO user_regions 
    FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true
    AND region IS NOT NULL;
    
    RETURN COALESCE(user_regions, ARRAY[]::text[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's allowed store IDs
CREATE OR REPLACE FUNCTION public.get_user_store_ids()
RETURNS uuid[] AS $$
DECLARE
    user_store_ids uuid[];
BEGIN
    SELECT store_ids INTO user_store_ids 
    FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND is_active = true
    AND store_ids IS NOT NULL;
    
    RETURN COALESCE(user_store_ids, ARRAY[]::uuid[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean AS $$
BEGIN
    RETURN public.get_user_role() = 'super_admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- BRANDS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on brands" ON public.brands
    FOR ALL USING (public.is_super_admin());

-- Others can only read
CREATE POLICY "Read access on brands" ON public.brands
    FOR SELECT USING (
        public.get_user_role() IN ('regional_manager', 'store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- PRODUCTS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on products" ON public.products
    FOR ALL USING (public.is_super_admin());

-- Others can only read
CREATE POLICY "Read access on products" ON public.products
    FOR SELECT USING (
        public.get_user_role() IN ('regional_manager', 'store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- STORES TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on stores" ON public.stores
    FOR ALL USING (public.is_super_admin());

-- Regional managers can access stores in their region
CREATE POLICY "Regional manager access on stores" ON public.stores
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND region = ANY(public.get_user_regions())
    );

-- Store managers can access their specific stores
CREATE POLICY "Store manager access on stores" ON public.stores
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND id = ANY(public.get_user_store_ids())
    );

-- Analysts can read all stores
CREATE POLICY "Analyst read access on stores" ON public.stores
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- CUSTOMERS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on customers" ON public.customers
    FOR ALL USING (public.is_super_admin());

-- Regional managers can access customers in their region
CREATE POLICY "Regional manager access on customers" ON public.customers
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND location_region = ANY(public.get_user_regions())
    );

-- Store managers and analysts can read all customers (for analytics)
CREATE POLICY "Store manager and analyst read access on customers" ON public.customers
    FOR SELECT USING (
        public.get_user_role() IN ('store_manager', 'analyst', 'api_service')
    );

-- =============================================
-- TRANSACTIONS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on transactions" ON public.transactions
    FOR ALL USING (public.is_super_admin());

-- Regional managers can access transactions from stores in their region
CREATE POLICY "Regional manager access on transactions" ON public.transactions
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

-- Store managers can access transactions from their stores
CREATE POLICY "Store manager access on transactions" ON public.transactions
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

-- Analysts and API service can read all transactions
CREATE POLICY "Analyst and API read access on transactions" ON public.transactions
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- TRANSACTION ITEMS TABLE RLS POLICIES
-- =============================================

-- Super admin can do everything
CREATE POLICY "Super admin full access on transaction_items" ON public.transaction_items
    FOR ALL USING (public.is_super_admin());

-- Regional managers can access transaction items from their region
CREATE POLICY "Regional manager access on transaction_items" ON public.transaction_items
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.transactions t
            JOIN public.stores s ON t.store_id = s.id
            WHERE t.id = transaction_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

-- Store managers can access transaction items from their stores
CREATE POLICY "Store manager access on transaction_items" ON public.transaction_items
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND EXISTS (
            SELECT 1 FROM public.transactions t
            WHERE t.id = transaction_id 
            AND t.store_id = ANY(public.get_user_store_ids())
        )
    );

-- Analysts and API service can read all transaction items
CREATE POLICY "Analyst and API read access on transaction_items" ON public.transaction_items
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- SUBSTITUTIONS TABLE RLS POLICIES
-- =============================================

-- Similar pattern for substitutions
CREATE POLICY "Super admin full access on substitutions" ON public.substitutions
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on substitutions" ON public.substitutions
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.transactions t
            JOIN public.stores s ON t.store_id = s.id
            WHERE t.id = transaction_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on substitutions" ON public.substitutions
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND EXISTS (
            SELECT 1 FROM public.transactions t
            WHERE t.id = transaction_id 
            AND t.store_id = ANY(public.get_user_store_ids())
        )
    );

CREATE POLICY "Analyst and API read access on substitutions" ON public.substitutions
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- DEVICE-RELATED TABLE RLS POLICIES
-- =============================================

-- Device Health policies
CREATE POLICY "Super admin full access on device_health" ON public.device_health
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on device_health" ON public.device_health
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on device_health" ON public.device_health
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

CREATE POLICY "API service access on device_health" ON public.device_health
    FOR ALL USING (public.get_user_role() = 'api_service');

-- Devices policies
CREATE POLICY "Super admin full access on devices" ON public.devices
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on devices" ON public.devices
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on devices" ON public.devices
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

CREATE POLICY "API service access on devices" ON public.devices
    FOR ALL USING (public.get_user_role() = 'api_service');

-- Edge Logs policies
CREATE POLICY "Super admin full access on edge_logs" ON public.edge_logs
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on edge_logs" ON public.edge_logs
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on edge_logs" ON public.edge_logs
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

CREATE POLICY "API service access on edge_logs" ON public.edge_logs
    FOR ALL USING (public.get_user_role() = 'api_service');

-- =============================================
-- BEHAVIORAL DATA RLS POLICIES
-- =============================================

-- Request Behaviors policies
CREATE POLICY "Super admin full access on request_behaviors" ON public.request_behaviors
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on request_behaviors" ON public.request_behaviors
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on request_behaviors" ON public.request_behaviors
    FOR SELECT USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

CREATE POLICY "Analyst and API read access on request_behaviors" ON public.request_behaviors
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- Customer Requests policies
CREATE POLICY "Super admin full access on customer_requests" ON public.customer_requests
    FOR ALL USING (public.is_super_admin());

CREATE POLICY "Regional manager access on customer_requests" ON public.customer_requests
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND EXISTS (
            SELECT 1 FROM public.stores s 
            WHERE s.id = store_id 
            AND s.region = ANY(public.get_user_regions())
        )
    );

CREATE POLICY "Store manager access on customer_requests" ON public.customer_requests
    FOR ALL USING (
        public.get_user_role() = 'store_manager' 
        AND store_id = ANY(public.get_user_store_ids())
    );

CREATE POLICY "Analyst read access on customer_requests" ON public.customer_requests
    FOR SELECT USING (
        public.get_user_role() IN ('analyst', 'api_service')
    );

-- =============================================
-- USER ROLES TABLE RLS POLICIES
-- =============================================

-- Super admin can manage all user roles
CREATE POLICY "Super admin full access on user_roles" ON public.user_roles
    FOR ALL USING (public.is_super_admin());

-- Users can read their own role information
CREATE POLICY "Users can read own role" ON public.user_roles
    FOR SELECT USING (user_id = auth.uid());

-- =============================================
-- GRANTS AND PERMISSIONS
-- =============================================

-- Grant necessary permissions to roles
GRANT USAGE ON SCHEMA public TO scout_super_admin, scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO scout_analyst;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO scout_api_service;
GRANT ALL ON ALL TABLES IN SCHEMA public TO scout_super_admin;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.get_user_role() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_regions() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_store_ids() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO PUBLIC;

-- =============================================
-- DEFAULT USER SETUP
-- =============================================

-- Create a function to setup default admin user (to be called after first deployment)
CREATE OR REPLACE FUNCTION public.setup_default_admin(admin_email text)
RETURNS void AS $$
BEGIN
    -- This function should be called manually after deployment
    -- with the email of the first admin user
    INSERT INTO public.user_roles (user_id, email, role, is_active)
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

COMMENT ON TABLE public.user_roles IS 'User role management with region and store-level access control';
COMMENT ON FUNCTION public.get_user_role() IS 'Returns the current user role for RLS policies';
COMMENT ON FUNCTION public.get_user_regions() IS 'Returns allowed regions for regional managers';
COMMENT ON FUNCTION public.get_user_store_ids() IS 'Returns allowed store IDs for store managers';
COMMENT ON FUNCTION public.setup_default_admin(text) IS 'Sets up the first super admin user - call manually after deployment';-- =============================================
-- Scout Analytics Dashboard - Analytical Views
-- Migration: 003_views.sql
-- Description: Analytical and BI views for dashboard panels
-- =============================================

-- =============================================
-- TRANSACTION TRENDS VIEW
-- =============================================

CREATE OR REPLACE VIEW public.vw_transaction_trends AS
SELECT 
    t.id,
    t.transaction_code,
    t.transaction_date,
    DATE_TRUNC('hour', t.transaction_date) as transaction_hour,
    DATE_TRUNC('day', t.transaction_date) as transaction_day,
    DATE_TRUNC('week', t.transaction_date) as transaction_week,
    DATE_TRUNC('month', t.transaction_date) as transaction_month,
    t.hour_of_day,
    t.is_weekend,
    CASE 
        WHEN t.hour_of_day BETWEEN 6 AND 11 THEN 'Morning'
        WHEN t.hour_of_day BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN t.hour_of_day BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END as time_period,
    t.total_amount,
    t.total_items,
    t.payment_method,
    t.discount_amount,
    t.tax_amount,
    s.region,
    s.province,
    s.city,
    s.barangay,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.location_region as customer_region,
    c.income_bracket as customer_income,
    c.loyalty_tier as customer_loyalty_tier,
    -- Calculated metrics
    (t.total_amount - t.discount_amount - t.tax_amount) as net_sales,
    (t.total_amount / NULLIF(t.total_items, 0)) as average_item_value,
    -- Time-based flags
    EXTRACT(DOW FROM t.transaction_date) as day_of_week,
    EXTRACT(MONTH FROM t.transaction_date) as month_number,
    EXTRACT(QUARTER FROM t.transaction_date) as quarter_number,
    EXTRACT(YEAR FROM t.transaction_date) as year_number
FROM public.transactions t
JOIN public.stores s ON t.store_id = s.id
LEFT JOIN public.customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years';

-- Index for performance
CREATE INDEX idx_vw_transaction_trends_date ON public.vw_transaction_trends(transaction_date);
CREATE INDEX idx_vw_transaction_trends_region_date ON public.vw_transaction_trends(region, transaction_date);

-- =============================================
-- PRODUCT MIX VIEW
-- =============================================

CREATE OR REPLACE VIEW public.vw_product_mix AS
SELECT 
    p.id as product_id,
    p.sku,
    p.name as product_name,
    p.category,
    p.subcategory,
    p.unit_size,
    p.unit_cost,
    p.retail_price,
    p.margin_percentage,
    b.id as brand_id,
    b.name as brand_name,
    b.category as brand_category,
    b.manufacturer,
    b.country_origin,
    ti.transaction_id,
    ti.quantity,
    ti.unit_price,
    ti.total_price,
    ti.discount_amount as item_discount,
    t.transaction_date,
    t.total_amount as transaction_total,
    s.region,
    s.province,
    s.city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    -- Calculated metrics
    (ti.total_price - ti.discount_amount) as net_item_revenue,
    (ti.quantity * p.unit_cost) as item_cost,
    ((ti.total_price - ti.discount_amount) - (ti.quantity * p.unit_cost)) as item_profit,
    CASE 
        WHEN (ti.quantity * p.unit_cost) > 0 
        THEN (((ti.total_price - ti.discount_amount) - (ti.quantity * p.unit_cost)) / (ti.quantity * p.unit_cost)) * 100
        ELSE 0
    END as item_margin_percentage,
    -- Market share calculations (requires window functions in queries)
    ti.total_price / t.total_amount * 100 as transaction_share_percentage
FROM public.transaction_items ti
JOIN public.transactions t ON ti.transaction_id = t.id
JOIN public.products p ON ti.product_id = p.id
JOIN public.brands b ON p.brand_id = b.id
JOIN public.stores s ON t.store_id = s.id
LEFT JOIN public.customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
  AND p.is_active = true
  AND b.is_active = true;

-- Index for performance
CREATE INDEX idx_vw_product_mix_category_date ON public.vw_product_mix(category, transaction_date);
CREATE INDEX idx_vw_product_mix_brand_date ON public.vw_product_mix(brand_name, transaction_date);

-- =============================================
-- SUBSTITUTIONS VIEW
-- =============================================

CREATE OR REPLACE VIEW public.vw_substitutions AS
SELECT 
    sub.id as substitution_id,
    sub.transaction_id,
    sub.was_accepted,
    sub.reason,
    sub.customer_satisfaction_score,
    t.transaction_date,
    t.total_amount as transaction_total,
    -- Original product details
    p_orig.id as original_product_id,
    p_orig.sku as original_sku,
    p_orig.name as original_product_name,
    p_orig.category as original_category,
    p_orig.subcategory as original_subcategory,
    p_orig.retail_price as original_price,
    b_orig.name as original_brand_name,
    -- Substitute product details
    p_sub.id as substitute_product_id,
    p_sub.sku as substitute_sku,
    p_sub.name as substitute_product_name,
    p_sub.category as substitute_category,
    p_sub.subcategory as substitute_subcategory,
    p_sub.retail_price as substitute_price,
    b_sub.name as substitute_brand_name,
    -- Price comparison
    (p_sub.retail_price - p_orig.retail_price) as price_difference,
    CASE 
        WHEN p_orig.retail_price > 0 
        THEN ((p_sub.retail_price - p_orig.retail_price) / p_orig.retail_price) * 100
        ELSE 0
    END as price_difference_percentage,
    -- Store and customer info
    s.region,
    s.province,
    s.city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.loyalty_tier as customer_loyalty_tier,
    -- Categorization
    CASE 
        WHEN p_orig.category = p_sub.category THEN 'Same Category'
        ELSE 'Cross Category'
    END as substitution_type,
    CASE 
        WHEN b_orig.name = b_sub.name THEN 'Same Brand'
        ELSE 'Brand Switch'
    END as brand_substitution_type
FROM public.substitutions sub
JOIN public.transactions t ON sub.transaction_id = t.id
JOIN public.products p_orig ON sub.original_product_id = p_orig.id
JOIN public.products p_sub ON sub.substitute_product_id = p_sub.id
JOIN public.brands b_orig ON p_orig.brand_id = b_orig.id
JOIN public.brands b_sub ON p_sub.brand_id = b_sub.id
JOIN public.stores s ON t.store_id = s.id
LEFT JOIN public.customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years';

-- Index for performance
CREATE INDEX idx_vw_substitutions_date ON public.vw_substitutions(transaction_date);
CREATE INDEX idx_vw_substitutions_acceptance ON public.vw_substitutions(was_accepted);

-- =============================================
-- CONSUMER BEHAVIOR VIEW
-- =============================================

CREATE OR REPLACE VIEW public.vw_consumer_behavior AS
SELECT 
    rb.id as behavior_id,
    rb.customer_id,
    rb.request_type,
    rb.request_category,
    rb.request_details,
    rb.response_time_ms,
    rb.was_successful,
    rb.timestamp as behavior_timestamp,
    DATE_TRUNC('hour', rb.timestamp) as behavior_hour,
    DATE_TRUNC('day', rb.timestamp) as behavior_day,
    EXTRACT(HOUR FROM rb.timestamp) as hour_of_day,
    EXTRACT(DOW FROM rb.timestamp) as day_of_week,
    CASE 
        WHEN EXTRACT(DOW FROM rb.timestamp) IN (0, 6) THEN true
        ELSE false
    END as is_weekend,
    -- Customer details
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.location_region as customer_region,
    c.location_province as customer_province,
    c.location_city as customer_city,
    c.income_bracket as customer_income,
    c.loyalty_tier as customer_loyalty_tier,
    -- Store details
    s.region as store_region,
    s.province as store_province,
    s.city as store_city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    -- Performance metrics
    CASE 
        WHEN rb.response_time_ms <= 1000 THEN 'Fast'
        WHEN rb.response_time_ms <= 3000 THEN 'Medium'
        ELSE 'Slow'
    END as response_speed_category,
    -- Request patterns
    CASE 
        WHEN rb.request_type LIKE '%product%' THEN 'Product Related'
        WHEN rb.request_type LIKE '%price%' THEN 'Price Related'
        WHEN rb.request_type LIKE '%location%' THEN 'Location Related'
        ELSE 'Other'
    END as request_pattern
FROM public.request_behaviors rb
JOIN public.stores s ON rb.store_id = s.id
LEFT JOIN public.customers c ON rb.customer_id = c.id
WHERE rb.timestamp >= CURRENT_DATE - INTERVAL '1 year';

-- Index for performance
CREATE INDEX idx_vw_consumer_behavior_timestamp ON public.vw_consumer_behavior(behavior_timestamp);
CREATE INDEX idx_vw_consumer_behavior_customer ON public.vw_consumer_behavior(customer_id);

-- =============================================
-- CONSUMER PROFILE VIEW
-- =============================================

CREATE OR REPLACE VIEW public.vw_consumer_profile AS
WITH customer_transaction_summary AS (
    SELECT 
        c.id as customer_id,
        COUNT(t.id) as total_transactions,
        SUM(t.total_amount) as total_spent,
        AVG(t.total_amount) as avg_transaction_value,
        SUM(t.total_items) as total_items_purchased,
        MIN(t.transaction_date) as first_transaction_date,
        MAX(t.transaction_date) as last_transaction_date,
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) as active_months,
        COUNT(DISTINCT t.store_id) as stores_visited
    FROM public.customers c
    LEFT JOIN public.transactions t ON c.id = t.customer_id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.id
),
customer_preferences AS (
    SELECT 
        c.id as customer_id,
        MODE() WITHIN GROUP (ORDER BY p.category) as preferred_category,
        MODE() WITHIN GROUP (ORDER BY b.name) as preferred_brand,
        MODE() WITHIN GROUP (ORDER BY s.type) as preferred_store_type,
        COUNT(DISTINCT p.category) as categories_purchased,
        COUNT(DISTINCT b.name) as brands_purchased
    FROM public.customers c
    JOIN public.transactions t ON c.id = t.customer_id
    JOIN public.transaction_items ti ON t.id = ti.transaction_id
    JOIN public.products p ON ti.product_id = p.id
    JOIN public.brands b ON p.brand_id = b.id
    JOIN public.stores s ON t.store_id = s.id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.id
)
SELECT 
    c.id as customer_id,
    c.customer_code,
    c.gender,
    c.age_group,
    c.location_region,
    c.location_province,
    c.location_city,
    c.location_barangay,
    c.income_bracket,
    c.loyalty_tier,
    c.created_at as customer_since,
    -- Transaction metrics
    COALESCE(cts.total_transactions, 0) as total_transactions,
    COALESCE(cts.total_spent, 0) as total_spent,
    COALESCE(cts.avg_transaction_value, 0) as avg_transaction_value,
    COALESCE(cts.total_items_purchased, 0) as total_items_purchased,
    cts.first_transaction_date,
    cts.last_transaction_date,
    COALESCE(cts.active_months, 0) as active_months,
    COALESCE(cts.stores_visited, 0) as stores_visited,
    -- Preferences
    cp.preferred_category,
    cp.preferred_brand,
    cp.preferred_store_type,
    COALESCE(cp.categories_purchased, 0) as categories_purchased,
    COALESCE(cp.brands_purchased, 0) as brands_purchased,
    -- Calculated segments
    CASE 
        WHEN cts.total_spent >= 50000 THEN 'High Value'
        WHEN cts.total_spent >= 20000 THEN 'Medium Value'
        WHEN cts.total_spent >= 5000 THEN 'Low Value'
        ELSE 'New/Inactive'
    END as value_segment,
    CASE 
        WHEN cts.total_transactions >= 50 THEN 'High Frequency'
        WHEN cts.total_transactions >= 20 THEN 'Medium Frequency'
        WHEN cts.total_transactions >= 5 THEN 'Low Frequency'
        ELSE 'New/Inactive'
    END as frequency_segment,
    -- Recency (days since last transaction)
    CASE 
        WHEN cts.last_transaction_date IS NULL THEN NULL
        ELSE CURRENT_DATE - cts.last_transaction_date::DATE
    END as days_since_last_transaction,
    -- Customer lifetime metrics
    CASE 
        WHEN cts.first_transaction_date IS NOT NULL AND cts.last_transaction_date IS NOT NULL 
        THEN cts.last_transaction_date::DATE - cts.first_transaction_date::DATE + 1
        ELSE NULL
    END as customer_lifetime_days
FROM public.customers c
LEFT JOIN customer_transaction_summary cts ON c.id = cts.customer_id
LEFT JOIN customer_preferences cp ON c.id = cp.customer_id
WHERE c.is_active = true;

-- Index for performance
CREATE INDEX idx_vw_consumer_profile_segments ON public.vw_consumer_profile(value_segment, frequency_segment);
CREATE INDEX idx_vw_consumer_profile_location ON public.vw_consumer_profile(location_region, location_province);

-- =============================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- =============================================

-- Daily transaction summary (materialized for better performance)
CREATE MATERIALIZED VIEW public.mv_daily_transaction_summary AS
SELECT 
    DATE_TRUNC('day', transaction_date) as transaction_day,
    region,
    province,
    city,
    store_type,
    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    SUM(total_items) as total_items_sold,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT store_id) as active_stores
FROM public.vw_transaction_trends
GROUP BY 
    DATE_TRUNC('day', transaction_date),
    region,
    province,
    city,
    store_type;

-- Create unique index for refresh
CREATE UNIQUE INDEX idx_mv_daily_summary_unique 
ON public.mv_daily_transaction_summary(transaction_day, region, province, city, store_type);

-- Product performance summary (materialized)
CREATE MATERIALIZED VIEW public.mv_product_performance_summary AS
SELECT 
    category,
    subcategory,
    brand_name,
    product_name,
    sku,
    DATE_TRUNC('month', transaction_date) as month,
    SUM(quantity) as total_quantity_sold,
    SUM(net_item_revenue) as total_revenue,
    AVG(item_margin_percentage) as avg_margin,
    COUNT(DISTINCT transaction_id) as transaction_count,
    COUNT(DISTINCT customer_gender) as unique_customers
FROM public.vw_product_mix
GROUP BY 
    category,
    subcategory,
    brand_name,
    product_name,
    sku,
    DATE_TRUNC('month', transaction_date);

-- Create unique index for refresh
CREATE UNIQUE INDEX idx_mv_product_performance_unique 
ON public.mv_product_performance_summary(category, subcategory, brand_name, product_name, sku, month);

-- =============================================
-- REFRESH FUNCTIONS FOR MATERIALIZED VIEWS
-- =============================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION public.refresh_analytical_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_daily_transaction_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_product_performance_summary;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- VIEW PERMISSIONS
-- =============================================

-- Grant access to views for all roles
GRANT SELECT ON public.vw_transaction_trends TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON public.vw_product_mix TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON public.vw_substitutions TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON public.vw_consumer_behavior TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON public.vw_consumer_profile TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;

-- Grant access to materialized views
GRANT SELECT ON public.mv_daily_transaction_summary TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT SELECT ON public.mv_product_performance_summary TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;

-- Grant execute permissions on refresh function
GRANT EXECUTE ON FUNCTION public.refresh_analytical_views() TO scout_super_admin, scout_api_service;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON VIEW public.vw_transaction_trends IS 'Comprehensive transaction analysis with time-based segmentation and geographic breakdowns';
COMMENT ON VIEW public.vw_product_mix IS 'Detailed product performance metrics with profitability calculations';
COMMENT ON VIEW public.vw_substitutions IS 'Product substitution patterns and acceptance analysis';
COMMENT ON VIEW public.vw_consumer_behavior IS 'Customer interaction patterns and request behavior analysis';
COMMENT ON VIEW public.vw_consumer_profile IS 'Complete customer profiling with RFM analysis and preferences';
COMMENT ON MATERIALIZED VIEW public.mv_daily_transaction_summary IS 'Pre-aggregated daily metrics for dashboard performance';
COMMENT ON MATERIALIZED VIEW public.mv_product_performance_summary IS 'Pre-aggregated monthly product performance metrics';
COMMENT ON FUNCTION public.refresh_analytical_views() IS 'Refreshes all materialized views for updated analytics data';-- =============================================
-- Scout Analytics Dashboard - Triggers & Automation
-- Migration: 004_triggers.sql
-- Description: Audit triggers, integrity checks, and automation
-- =============================================

-- =============================================
-- AUDIT TABLE
-- =============================================

CREATE TABLE public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name text NOT NULL,
    operation text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id uuid NOT NULL,
    old_values jsonb,
    new_values jsonb,
    user_id uuid,
    timestamp timestamp with time zone DEFAULT now()
);

CREATE INDEX idx_audit_logs_table_operation ON public.audit_logs(table_name, operation);
CREATE INDEX idx_audit_logs_timestamp ON public.audit_logs(timestamp);

-- Enable RLS on audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- =============================================
-- UPDATE TRIGGERS FOR TIMESTAMP AUTOMATION
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to all tables with updated_at
DO $$
DECLARE
    tabname text;
BEGIN
    FOREACH tabname IN ARRAY ARRAY[
        'brands', 'customers', 'products', 'stores', 'transactions', 
        'transaction_items', 'substitutions', 'devices', 'customer_requests',
        'device_health', 'edge_logs', 'request_behaviors', 'user_roles'
    ]
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at_%I ON public.%I;', tabname, tabname);
        EXECUTE format('CREATE TRIGGER set_updated_at_%I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();', tabname, tabname);
    END LOOP;
END;
$$;

-- =============================================
-- AUDIT TRIGGERS
-- =============================================

-- Generic audit function
CREATE OR REPLACE FUNCTION public.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (table_name, operation, record_id, old_values, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.id, row_to_json(OLD), auth.uid());
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (table_name, operation, record_id, old_values, new_values, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(OLD), row_to_json(NEW), auth.uid());
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (table_name, operation, record_id, new_values, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(NEW), auth.uid());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to all main tables
DO $$
DECLARE
    tabname text;
BEGIN
    FOREACH tabname IN ARRAY ARRAY[
        'brands', 'products', 'customers', 'stores', 'transactions', 
        'transaction_items', 'substitutions', 'devices', 'customer_requests'
    ]
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS audit_%I ON public.%I;', tabname, tabname);
        EXECUTE format('CREATE TRIGGER audit_%I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();', tabname, tabname);
    END LOOP;
END;
$$;

-- =============================================
-- DATA INTEGRITY TRIGGERS
-- =============================================

-- Function to validate transaction totals
CREATE OR REPLACE FUNCTION public.validate_transaction_totals()
RETURNS TRIGGER AS $$
DECLARE
    calculated_total numeric;
BEGIN
    -- Calculate total from transaction items
    SELECT COALESCE(SUM(total_price - discount_amount), 0)
    INTO calculated_total
    FROM public.transaction_items
    WHERE transaction_id = NEW.transaction_id;
    
    -- Update transaction total if it differs significantly
    IF ABS(calculated_total - (SELECT total_amount FROM public.transactions WHERE id = NEW.transaction_id)) > 0.01 THEN
        UPDATE public.transactions 
        SET total_amount = calculated_total,
            total_items = (SELECT COUNT(*) FROM public.transaction_items WHERE transaction_id = NEW.transaction_id)
        WHERE id = NEW.transaction_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to maintain transaction totals
CREATE TRIGGER validate_transaction_totals
    AFTER INSERT OR UPDATE OR DELETE ON public.transaction_items
    FOR EACH ROW EXECUTE FUNCTION public.validate_transaction_totals();

-- =============================================
-- BUSINESS LOGIC TRIGGERS
-- =============================================

-- Function to auto-generate customer codes
CREATE OR REPLACE FUNCTION public.generate_customer_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_code IS NULL THEN
        NEW.customer_code := 'CUST-' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 8));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for customer code generation
CREATE TRIGGER generate_customer_code
    BEFORE INSERT ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.generate_customer_code();

-- Function to auto-generate transaction codes
CREATE OR REPLACE FUNCTION public.generate_transaction_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.transaction_code IS NULL THEN
        NEW.transaction_code := 'TXN-' || TO_CHAR(NEW.transaction_date, 'YYYYMMDD') || '-' || 
                               UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for transaction code generation
CREATE TRIGGER generate_transaction_code
    BEFORE INSERT ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.generate_transaction_code();

-- =============================================
-- NOTIFICATION TRIGGERS
-- =============================================

-- Function to notify on high-value transactions
CREATE OR REPLACE FUNCTION public.notify_high_value_transaction()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify if transaction is over 10,000 PHP
    IF NEW.total_amount > 10000 THEN
        PERFORM pg_notify(
            'high_value_transaction',
            json_build_object(
                'transaction_id', NEW.id,
                'amount', NEW.total_amount,
                'store_id', NEW.store_id,
                'timestamp', NEW.transaction_date
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for high-value transaction notifications
CREATE TRIGGER notify_high_value_transaction
    AFTER INSERT ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.notify_high_value_transaction();

-- Function to notify on device errors
CREATE OR REPLACE FUNCTION public.notify_device_error()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify if device status changes to error
    IF NEW.status = 'error' AND (OLD.status IS NULL OR OLD.status != 'error') THEN
        PERFORM pg_notify(
            'device_error',
            json_build_object(
                'device_id', NEW.device_id,
                'store_id', NEW.store_id,
                'error_count', NEW.error_count,
                'timestamp', NEW.created_at
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for device error notifications
CREATE TRIGGER notify_device_error
    AFTER INSERT OR UPDATE ON public.device_health
    FOR EACH ROW EXECUTE FUNCTION public.notify_device_error();

-- =============================================
-- MATERIALIZED VIEW REFRESH TRIGGERS
-- =============================================

-- Function to schedule materialized view refresh
CREATE OR REPLACE FUNCTION public.schedule_mv_refresh()
RETURNS TRIGGER AS $$
BEGIN
    -- Schedule refresh of materialized views after significant data changes
    -- This would typically integrate with a job scheduler
    PERFORM pg_notify('refresh_materialized_views', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to schedule MV refresh on transaction changes
CREATE TRIGGER schedule_mv_refresh_transactions
    AFTER INSERT ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.schedule_mv_refresh();

-- =============================================
-- DATA QUALITY TRIGGERS
-- =============================================

-- Function to validate product pricing
CREATE OR REPLACE FUNCTION public.validate_product_pricing()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure retail price is higher than unit cost
    IF NEW.retail_price <= NEW.unit_cost THEN
        RAISE WARNING 'Product % has retail price (%) lower than or equal to unit cost (%)', 
                     NEW.name, NEW.retail_price, NEW.unit_cost;
    END IF;
    
    -- Ensure reasonable margin (warn if margin is over 500% or negative)
    IF NEW.unit_cost > 0 THEN
        IF ((NEW.retail_price - NEW.unit_cost) / NEW.unit_cost) > 5.0 THEN
            RAISE WARNING 'Product % has unusually high margin: %', 
                         NEW.name, ((NEW.retail_price - NEW.unit_cost) / NEW.unit_cost) * 100;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for product pricing validation
CREATE TRIGGER validate_product_pricing
    BEFORE INSERT OR UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.validate_product_pricing();

-- =============================================
-- ARCHIVAL TRIGGERS
-- =============================================

-- Function to archive old transactions
CREATE OR REPLACE FUNCTION public.archive_old_data()
RETURNS void AS $$
BEGIN
    -- This function can be called periodically to archive old data
    -- Archive transactions older than 3 years to archive tables
    
    -- Create archive table if it doesn't exist
    CREATE TABLE IF NOT EXISTS public.transactions_archive (LIKE public.transactions INCLUDING ALL);
    
    -- Move old transactions to archive
    WITH archived_transactions AS (
        DELETE FROM public.transactions 
        WHERE transaction_date < CURRENT_DATE - INTERVAL '3 years'
        RETURNING *
    )
    INSERT INTO public.transactions_archive 
    SELECT * FROM archived_transactions;
    
    -- Clean up old audit logs (keep 1 year)
    DELETE FROM public.audit_logs 
    WHERE timestamp < CURRENT_DATE - INTERVAL '1 year';
    
    -- Clean up old device health records (keep 6 months)
    DELETE FROM public.device_health 
    WHERE created_at < CURRENT_DATE - INTERVAL '6 months';
    
    -- Clean up old edge logs (keep 3 months)
    DELETE FROM public.edge_logs 
    WHERE timestamp < CURRENT_DATE - INTERVAL '3 months';
    
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- AUDIT LOG RLS POLICIES
-- =============================================

-- Super admin can read all audit logs
CREATE POLICY "Super admin read access on audit_logs" ON public.audit_logs
    FOR SELECT USING (public.is_super_admin());

-- Regional managers can read audit logs for their region (where applicable)
CREATE POLICY "Regional manager limited audit access" ON public.audit_logs
    FOR SELECT USING (
        public.get_user_role() = 'regional_manager' 
        AND table_name IN ('transactions', 'transaction_items', 'stores', 'devices', 'device_health')
    );

-- =============================================
-- PERMISSIONS
-- =============================================

-- Grant access to audit logs
GRANT SELECT ON public.audit_logs TO scout_super_admin;
GRANT SELECT ON public.audit_logs TO scout_regional_manager;

-- Grant execute permissions on utility functions
GRANT EXECUTE ON FUNCTION public.archive_old_data() TO scout_super_admin;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE public.audit_logs IS 'Comprehensive audit trail for all data changes with user tracking';
COMMENT ON FUNCTION public.set_updated_at() IS 'Automatically updates the updated_at timestamp on row modifications';
COMMENT ON FUNCTION public.audit_trigger_function() IS 'Generic audit function that logs all INSERT/UPDATE/DELETE operations';
COMMENT ON FUNCTION public.validate_transaction_totals() IS 'Ensures transaction totals match sum of transaction items';
COMMENT ON FUNCTION public.generate_customer_code() IS 'Auto-generates customer codes if not provided';
COMMENT ON FUNCTION public.generate_transaction_code() IS 'Auto-generates transaction codes with date and ID components';
COMMENT ON FUNCTION public.notify_high_value_transaction() IS 'Sends notifications for transactions over 10,000 PHP';
COMMENT ON FUNCTION public.notify_device_error() IS 'Sends notifications when devices enter error state';
COMMENT ON FUNCTION public.validate_product_pricing() IS 'Validates product pricing for reasonable margins and relationships';
COMMENT ON FUNCTION public.archive_old_data() IS 'Archives old data to maintain database performance - run periodically';-- =============================================
-- Scout Analytics Dashboard - Utility Functions
-- Migration: 005_functions.sql
-- Description: Reporting, analytics, and utility functions
-- =============================================

-- =============================================
-- ANALYTICS FUNCTIONS
-- =============================================

-- Function to get dashboard KPIs
CREATE OR REPLACE FUNCTION public.get_dashboard_kpis(
    start_date date DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date date DEFAULT CURRENT_DATE,
    region_filter text DEFAULT 'all',
    store_type_filter text DEFAULT 'all'
)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    total_transactions bigint;
    total_revenue numeric;
    avg_basket_value numeric;
    unique_customers bigint;
    repeat_purchase_rate numeric;
    top_category text;
    growth_rate numeric;
BEGIN
    -- Build base query with filters
    WITH filtered_transactions AS (
        SELECT t.*, s.region, s.type as store_type
        FROM public.transactions t
        JOIN public.stores s ON t.store_id = s.id
        WHERE t.transaction_date BETWEEN start_date AND end_date
        AND (region_filter = 'all' OR s.region = region_filter)
        AND (store_type_filter = 'all' OR s.type = store_type_filter)
    ),
    kpi_calculations AS (
        SELECT 
            COUNT(*) as total_transactions,
            SUM(total_amount) as total_revenue,
            AVG(total_amount) as avg_basket_value,
            COUNT(DISTINCT customer_id) as unique_customers
        FROM filtered_transactions
    ),
    repeat_customers AS (
        SELECT COUNT(DISTINCT customer_id) as repeat_count
        FROM filtered_transactions
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ),
    top_category_calc AS (
        SELECT p.category, SUM(ti.total_price) as category_revenue
        FROM filtered_transactions t
        JOIN public.transaction_items ti ON t.id = ti.transaction_id
        JOIN public.products p ON ti.product_id = p.id
        GROUP BY p.category
        ORDER BY category_revenue DESC
        LIMIT 1
    ),
    previous_period AS (
        SELECT SUM(total_amount) as prev_revenue
        FROM public.transactions t
        JOIN public.stores s ON t.store_id = s.id
        WHERE t.transaction_date BETWEEN (start_date - (end_date - start_date)) AND start_date
        AND (region_filter = 'all' OR s.region = region_filter)
        AND (store_type_filter = 'all' OR s.type = store_type_filter)
    )
    SELECT 
        k.total_transactions,
        k.total_revenue,
        k.avg_basket_value,
        k.unique_customers,
        COALESCE(rc.repeat_count::numeric / NULLIF(k.unique_customers, 0), 0) as repeat_purchase_rate,
        COALESCE(tc.category, 'N/A') as top_category,
        CASE 
            WHEN pp.prev_revenue > 0 THEN 
                ((k.total_revenue - pp.prev_revenue) / pp.prev_revenue) * 100
            ELSE 0
        END as growth_rate
    INTO total_transactions, total_revenue, avg_basket_value, unique_customers, 
         repeat_purchase_rate, top_category, growth_rate
    FROM kpi_calculations k
    CROSS JOIN repeat_customers rc
    CROSS JOIN top_category_calc tc
    CROSS JOIN previous_period pp;
    
    -- Build result JSON
    result := jsonb_build_object(
        'totalTransactions', total_transactions,
        'totalRevenue', total_revenue,
        'avgBasketValue', ROUND(avg_basket_value, 2),
        'uniqueCustomers', unique_customers,
        'repeatPurchaseRate', ROUND(repeat_purchase_rate * 100, 1),
        'topCategory', top_category,
        'growthRate', ROUND(growth_rate, 1),
        'period', jsonb_build_object(
            'startDate', start_date,
            'endDate', end_date,
            'regionFilter', region_filter,
            'storeTypeFilter', store_type_filter
        )
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get transaction trends data
CREATE OR REPLACE FUNCTION public.get_transaction_trends(
    start_date date DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date date DEFAULT CURRENT_DATE,
    granularity text DEFAULT 'daily',
    region_filter text DEFAULT 'all',
    store_type_filter text DEFAULT 'all'
)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    date_trunc_expr text;
BEGIN
    -- Set date truncation based on granularity
    CASE granularity
        WHEN 'hourly' THEN date_trunc_expr := 'hour';
        WHEN 'weekly' THEN date_trunc_expr := 'week';
        WHEN 'monthly' THEN date_trunc_expr := 'month';
        ELSE date_trunc_expr := 'day';
    END CASE;
    
    -- Build and execute dynamic query
    EXECUTE format('
        WITH trend_data AS (
            SELECT 
                DATE_TRUNC(%L, t.transaction_date) as period,
                COUNT(*) as transaction_count,
                SUM(t.total_amount) as revenue,
                AVG(t.total_amount) as avg_transaction_value,
                COUNT(DISTINCT t.customer_id) as unique_customers,
                s.region
            FROM public.transactions t
            JOIN public.stores s ON t.store_id = s.id
            WHERE t.transaction_date BETWEEN %L AND %L
            AND (%L = ''all'' OR s.region = %L)
            AND (%L = ''all'' OR s.type = %L)
            GROUP BY DATE_TRUNC(%L, t.transaction_date), s.region
            ORDER BY period
        )
        SELECT jsonb_agg(
            jsonb_build_object(
                ''period'', period,
                ''transactionCount'', transaction_count,
                ''revenue'', revenue,
                ''avgTransactionValue'', ROUND(avg_transaction_value, 2),
                ''uniqueCustomers'', unique_customers,
                ''region'', region
            )
        ) FROM trend_data',
        date_trunc_expr, start_date, end_date, region_filter, region_filter,
        store_type_filter, store_type_filter, date_trunc_expr
    ) INTO result;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get product performance data
CREATE OR REPLACE FUNCTION public.get_product_performance(
    start_date date DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date date DEFAULT CURRENT_DATE,
    category_filter text DEFAULT 'all',
    brand_filter text DEFAULT 'all',
    limit_count integer DEFAULT 50
)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    WITH product_performance AS (
        SELECT 
            p.id,
            p.sku,
            p.name as product_name,
            p.category,
            p.subcategory,
            b.name as brand_name,
            SUM(ti.quantity) as total_quantity,
            SUM(ti.total_price - ti.discount_amount) as total_revenue,
            COUNT(DISTINCT ti.transaction_id) as transaction_count,
            AVG(p.margin_percentage) as avg_margin,
            SUM(ti.quantity * p.unit_cost) as total_cost,
            COUNT(DISTINCT t.customer_id) as unique_customers
        FROM public.transaction_items ti
        JOIN public.transactions t ON ti.transaction_id = t.id
        JOIN public.products p ON ti.product_id = p.id
        JOIN public.brands b ON p.brand_id = b.id
        WHERE t.transaction_date BETWEEN start_date AND end_date
        AND (category_filter = 'all' OR p.category = category_filter)
        AND (brand_filter = 'all' OR b.name = brand_filter)
        GROUP BY p.id, p.sku, p.name, p.category, p.subcategory, b.name
        ORDER BY total_revenue DESC
        LIMIT limit_count
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'productId', id,
            'sku', sku,
            'productName', product_name,
            'category', category,
            'subcategory', subcategory,
            'brandName', brand_name,
            'totalQuantity', total_quantity,
            'totalRevenue', total_revenue,
            'transactionCount', transaction_count,
            'avgMargin', ROUND(avg_margin, 2),
            'totalCost', total_cost,
            'uniqueCustomers', unique_customers,
            'profitability', ROUND(total_revenue - total_cost, 2)
        )
    ) INTO result
    FROM product_performance;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get customer segmentation data
CREATE OR REPLACE FUNCTION public.get_customer_segmentation(
    start_date date DEFAULT CURRENT_DATE - INTERVAL '90 days',
    end_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    WITH customer_metrics AS (
        SELECT 
            c.id,
            c.customer_code,
            c.age_group,
            c.gender,
            c.income_bracket,
            c.location_region,
            COUNT(t.id) as transaction_count,
            SUM(t.total_amount) as total_spent,
            AVG(t.total_amount) as avg_transaction_value,
            MAX(t.transaction_date) as last_transaction_date,
            MIN(t.transaction_date) as first_transaction_date
        FROM public.customers c
        LEFT JOIN public.transactions t ON c.id = t.customer_id
        WHERE t.transaction_date BETWEEN start_date AND end_date
        GROUP BY c.id, c.customer_code, c.age_group, c.gender, c.income_bracket, c.location_region
    ),
    segmented_customers AS (
        SELECT 
            *,
            CASE 
                WHEN total_spent >= 50000 THEN 'High Value'
                WHEN total_spent >= 20000 THEN 'Medium Value'
                WHEN total_spent >= 5000 THEN 'Low Value'
                ELSE 'New/Inactive'
            END as value_segment,
            CASE 
                WHEN transaction_count >= 20 THEN 'High Frequency'
                WHEN transaction_count >= 10 THEN 'Medium Frequency'
                WHEN transaction_count >= 3 THEN 'Low Frequency'
                ELSE 'One-time'
            END as frequency_segment,
            CURRENT_DATE - last_transaction_date::date as days_since_last_transaction
        FROM customer_metrics
    )
    SELECT jsonb_build_object(
        'segmentSummary', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'segment', value_segment || ' - ' || frequency_segment,
                    'customerCount', count(*),
                    'totalRevenue', SUM(total_spent),
                    'avgTransactionValue', ROUND(AVG(avg_transaction_value), 2)
                )
            )
            FROM segmented_customers
            GROUP BY value_segment, frequency_segment
        ),
        'demographicBreakdown', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'demographic', age_group || ' - ' || gender,
                    'customerCount', count(*),
                    'avgSpend', ROUND(AVG(total_spent), 2),
                    'region', location_region
                )
            )
            FROM segmented_customers
            GROUP BY age_group, gender, location_region
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- UTILITY FUNCTIONS
-- =============================================

-- Function to get database health metrics
CREATE OR REPLACE FUNCTION public.get_database_health()
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    total_transactions bigint;
    total_customers bigint;
    total_products bigint;
    total_stores bigint;
    avg_transaction_size numeric;
    data_quality_score numeric;
BEGIN
    -- Get basic counts
    SELECT COUNT(*) INTO total_transactions FROM public.transactions;
    SELECT COUNT(*) INTO total_customers FROM public.customers WHERE is_active = true;
    SELECT COUNT(*) INTO total_products FROM public.products WHERE is_active = true;
    SELECT COUNT(*) INTO total_stores FROM public.stores WHERE is_active = true;
    
    -- Calculate average transaction size
    SELECT AVG(total_amount) INTO avg_transaction_size FROM public.transactions 
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days';
    
    -- Calculate data quality score (simplified)
    WITH quality_checks AS (
        SELECT 
            (SELECT COUNT(*) FROM public.transactions WHERE customer_id IS NULL)::numeric as missing_customers,
            (SELECT COUNT(*) FROM public.products WHERE unit_cost = 0)::numeric as zero_cost_products,
            (SELECT COUNT(*) FROM public.transactions WHERE total_amount <= 0)::numeric as invalid_transactions,
            total_transactions::numeric as total_records
    )
    SELECT 100 - ((missing_customers + zero_cost_products + invalid_transactions) / total_records * 100)
    INTO data_quality_score FROM quality_checks;
    
    result := jsonb_build_object(
        'totalTransactions', total_transactions,
        'totalCustomers', total_customers,
        'totalProducts', total_products,
        'totalStores', total_stores,
        'avgTransactionSize', ROUND(avg_transaction_size, 2),
        'dataQualityScore', ROUND(data_quality_score, 1),
        'lastUpdated', NOW()
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean and normalize data
CREATE OR REPLACE FUNCTION public.clean_transaction_data()
RETURNS text AS $$
DECLARE
    cleaned_count integer := 0;
    result_message text;
BEGIN
    -- Remove transactions with zero or negative amounts
    WITH deleted_transactions AS (
        DELETE FROM public.transactions 
        WHERE total_amount <= 0 
        RETURNING id
    )
    SELECT COUNT(*) INTO cleaned_count FROM deleted_transactions;
    
    -- Update null customer regions based on store regions
    UPDATE public.customers c
    SET location_region = s.region
    FROM public.transactions t
    JOIN public.stores s ON t.store_id = s.id
    WHERE c.id = t.customer_id 
    AND c.location_region IS NULL;
    
    -- Recalculate transaction totals where they don't match item totals
    UPDATE public.transactions t
    SET total_amount = calculated.item_total,
        total_items = calculated.item_count
    FROM (
        SELECT 
            ti.transaction_id,
            SUM(ti.total_price - COALESCE(ti.discount_amount, 0)) as item_total,
            COUNT(*) as item_count
        FROM public.transaction_items ti
        GROUP BY ti.transaction_id
    ) calculated
    WHERE t.id = calculated.transaction_id
    AND ABS(t.total_amount - calculated.item_total) > 0.01;
    
    result_message := format('Data cleaning completed. Removed %s invalid transactions and updated totals.', cleaned_count);
    
    RETURN result_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate test data summary
CREATE OR REPLACE FUNCTION public.get_data_summary()
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    WITH summary_stats AS (
        SELECT 
            (SELECT COUNT(*) FROM public.brands) as brand_count,
            (SELECT COUNT(*) FROM public.products) as product_count,
            (SELECT COUNT(*) FROM public.customers) as customer_count,
            (SELECT COUNT(*) FROM public.stores) as store_count,
            (SELECT COUNT(*) FROM public.transactions) as transaction_count,
            (SELECT COUNT(*) FROM public.transaction_items) as transaction_item_count,
            (SELECT SUM(total_amount) FROM public.transactions) as total_revenue,
            (SELECT MIN(transaction_date) FROM public.transactions) as earliest_transaction,
            (SELECT MAX(transaction_date) FROM public.transactions) as latest_transaction,
            (SELECT COUNT(DISTINCT region) FROM public.stores) as region_count,
            (SELECT COUNT(DISTINCT category) FROM public.products) as category_count
    )
    SELECT jsonb_build_object(
        'datasetSummary', jsonb_build_object(
            'brands', brand_count,
            'products', product_count,
            'customers', customer_count,
            'stores', store_count,
            'transactions', transaction_count,
            'transactionItems', transaction_item_count,
            'regions', region_count,
            'categories', category_count
        ),
        'businessMetrics', jsonb_build_object(
            'totalRevenue', total_revenue,
            'avgTransactionValue', ROUND(total_revenue / NULLIF(transaction_count, 0), 2),
            'avgItemsPerTransaction', ROUND(transaction_item_count::numeric / NULLIF(transaction_count, 0), 2)
        ),
        'dateRange', jsonb_build_object(
            'earliestTransaction', earliest_transaction,
            'latestTransaction', latest_transaction,
            'daysCovered', (latest_transaction - earliest_transaction)
        ),
        'generatedAt', NOW()
    ) INTO result
    FROM summary_stats;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- PERMISSIONS
-- =============================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION public.get_dashboard_kpis(date, date, text, text) TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT EXECUTE ON FUNCTION public.get_transaction_trends(date, date, text, text, text) TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT EXECUTE ON FUNCTION public.get_product_performance(date, date, text, text, integer) TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT EXECUTE ON FUNCTION public.get_customer_segmentation(date, date) TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT EXECUTE ON FUNCTION public.get_database_health() TO scout_super_admin, scout_api_service;
GRANT EXECUTE ON FUNCTION public.get_data_summary() TO scout_regional_manager, scout_store_manager, scout_analyst, scout_api_service;
GRANT EXECUTE ON FUNCTION public.clean_transaction_data() TO scout_super_admin;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON FUNCTION public.get_dashboard_kpis(date, date, text, text) IS 'Returns comprehensive KPI metrics for dashboard display with filtering options';
COMMENT ON FUNCTION public.get_transaction_trends(date, date, text, text, text) IS 'Returns transaction trend data with configurable granularity and filters';
COMMENT ON FUNCTION public.get_product_performance(date, date, text, text, integer) IS 'Returns detailed product performance metrics with filtering and ranking';
COMMENT ON FUNCTION public.get_customer_segmentation(date, date) IS 'Returns customer segmentation analysis with RFM-style classification';
COMMENT ON FUNCTION public.get_database_health() IS 'Returns database health metrics and data quality indicators';
COMMENT ON FUNCTION public.clean_transaction_data() IS 'Performs data cleaning operations to maintain data integrity';
COMMENT ON FUNCTION public.get_data_summary() IS 'Returns comprehensive summary of dataset for verification and reporting';-- =============================================
-- Scout Analytics Dashboard - Seed Data
-- Migration: 007_seed_data.sql
-- Description: Deterministic seed data for testing and development
-- =============================================

-- =============================================
-- BRANDS SEED DATA
-- =============================================

INSERT INTO public.brands (id, name, category, manufacturer, country_origin) VALUES
-- TBWA Client Brands
(gen_random_uuid(), 'Coca-Cola', 'Beverages', 'The Coca-Cola Company', 'USA'),
(gen_random_uuid(), 'McDonald''s', 'Food & Beverage', 'McDonald''s Corporation', 'USA'),
(gen_random_uuid(), 'Nissan', 'Automotive', 'Nissan Motor Company', 'Japan'),
(gen_random_uuid(), 'Adidas', 'Sportswear', 'Adidas AG', 'Germany'),
(gen_random_uuid(), 'Globe Telecom', 'Telecommunications', 'Globe Telecom Inc.', 'Philippines'),

-- Competitor Brands
(gen_random_uuid(), 'Pepsi', 'Beverages', 'PepsiCo Inc.', 'USA'),
(gen_random_uuid(), 'Jollibee', 'Food & Beverage', 'Jollibee Foods Corporation', 'Philippines'),
(gen_random_uuid(), 'Toyota', 'Automotive', 'Toyota Motor Corporation', 'Japan'),
(gen_random_uuid(), 'Nike', 'Sportswear', 'Nike Inc.', 'USA'),
(gen_random_uuid(), 'Smart Communications', 'Telecommunications', 'Smart Communications Inc.', 'Philippines'),

-- Additional FMCG Brands
(gen_random_uuid(), 'San Miguel', 'Beverages', 'San Miguel Corporation', 'Philippines'),
(gen_random_uuid(), 'Nestle', 'Food & Beverage', 'Nestlé S.A.', 'Switzerland'),
(gen_random_uuid(), 'Unilever', 'Personal Care', 'Unilever PLC', 'Netherlands'),
(gen_random_uuid(), 'Procter & Gamble', 'Personal Care', 'Procter & Gamble Co.', 'USA'),
(gen_random_uuid(), 'Colgate-Palmolive', 'Personal Care', 'Colgate-Palmolive Company', 'USA');

-- =============================================
-- PRODUCTS SEED DATA
-- =============================================

WITH brand_ids AS (
    SELECT id, name FROM public.brands
)
INSERT INTO public.products (brand_id, sku, name, category, subcategory, unit_size, unit_cost, retail_price) 
SELECT 
    b.id,
    products_data.sku,
    products_data.name,
    products_data.category,
    products_data.subcategory,
    products_data.unit_size,
    products_data.unit_cost,
    products_data.retail_price
FROM brand_ids b
CROSS JOIN LATERAL (VALUES
    -- Coca-Cola Products
    ('COKE-350ML', 'Coca-Cola Classic 350ml', 'Beverages', 'Soft Drinks', '350ml', 12.00, 18.00),
    ('COKE-500ML', 'Coca-Cola Classic 500ml', 'Beverages', 'Soft Drinks', '500ml', 16.00, 25.00),
    ('COKE-1L', 'Coca-Cola Classic 1L', 'Beverages', 'Soft Drinks', '1L', 28.00, 45.00),
    ('SPRITE-350ML', 'Sprite 350ml', 'Beverages', 'Soft Drinks', '350ml', 12.00, 18.00),
    ('FANTA-350ML', 'Fanta Orange 350ml', 'Beverages', 'Soft Drinks', '350ml', 12.00, 18.00),
    
    -- McDonald's Products  
    ('MCD-BURGER', 'Big Mac Burger', 'Food & Beverage', 'Fast Food', 'Single', 85.00, 150.00),
    ('MCD-FRIES', 'McDonald''s Fries Large', 'Food & Beverage', 'Fast Food', 'Large', 25.00, 65.00),
    ('MCD-NUGGETS', 'Chicken McNuggets 6pc', 'Food & Beverage', 'Fast Food', '6 pieces', 45.00, 95.00),
    ('MCD-COFFEE', 'McCafe Coffee', 'Food & Beverage', 'Beverages', 'Regular', 15.00, 45.00),
    ('MCD-SUNDAE', 'Hot Fudge Sundae', 'Food & Beverage', 'Desserts', 'Regular', 20.00, 55.00),
    
    -- Pepsi Products
    ('PEPSI-350ML', 'Pepsi Cola 350ml', 'Beverages', 'Soft Drinks', '350ml', 11.50, 17.50),
    ('PEPSI-500ML', 'Pepsi Cola 500ml', 'Beverages', 'Soft Drinks', '500ml', 15.50, 24.00),
    ('7UP-350ML', '7UP Lemon Lime 350ml', 'Beverages', 'Soft Drinks', '350ml', 11.50, 17.50),
    ('MIRINDA-350ML', 'Mirinda Orange 350ml', 'Beverages', 'Soft Drinks', '350ml', 11.50, 17.50),
    ('MOUNTAIN-DEW', 'Mountain Dew 350ml', 'Beverages', 'Soft Drinks', '350ml', 12.00, 18.50),
    
    -- Jollibee Products
    ('JB-CHICKENJOY', 'Chickenjoy 1pc', 'Food & Beverage', 'Fast Food', '1 piece', 75.00, 135.00),
    ('JB-BURGER', 'Yumburger', 'Food & Beverage', 'Fast Food', 'Single', 40.00, 85.00),
    ('JB-SPAGHETTI', 'Jolly Spaghetti', 'Food & Beverage', 'Fast Food', 'Regular', 55.00, 110.00),
    ('JB-PEACH-PIE', 'Peach Mango Pie', 'Food & Beverage', 'Desserts', 'Single', 18.00, 45.00),
    ('JB-COFFEE', 'Jollibee Coffee', 'Food & Beverage', 'Beverages', 'Regular', 12.00, 35.00)
) AS products_data(sku, name, category, subcategory, unit_size, unit_cost, retail_price)
WHERE (
    (b.name = 'Coca-Cola' AND products_data.sku LIKE 'COKE%' OR products_data.sku LIKE 'SPRITE%' OR products_data.sku LIKE 'FANTA%') OR
    (b.name = 'McDonald''s' AND products_data.sku LIKE 'MCD%') OR
    (b.name = 'Pepsi' AND products_data.sku LIKE 'PEPSI%' OR products_data.sku LIKE '7UP%' OR products_data.sku LIKE 'MIRINDA%' OR products_data.sku LIKE 'MOUNTAIN%') OR
    (b.name = 'Jollibee' AND products_data.sku LIKE 'JB%')
);

-- Add more FMCG products for other brands
WITH brand_ids AS (
    SELECT id, name FROM public.brands WHERE name IN ('San Miguel', 'Nestle', 'Unilever', 'Procter & Gamble', 'Colgate-Palmolive')
)
INSERT INTO public.products (brand_id, sku, name, category, subcategory, unit_size, unit_cost, retail_price)
SELECT 
    b.id,
    products_data.sku,
    products_data.name,
    products_data.category,
    products_data.subcategory,
    products_data.unit_size,
    products_data.unit_cost,
    products_data.retail_price
FROM brand_ids b
CROSS JOIN LATERAL (VALUES
    -- San Miguel Products
    ('SMB-BEER-330ML', 'San Miguel Pale Pilsen 330ml', 'Beverages', 'Beer', '330ml', 28.00, 45.00),
    ('SMB-LIGHT-330ML', 'San Miguel Light 330ml', 'Beverages', 'Beer', '330ml', 28.00, 45.00),
    ('SMB-PREMIUM', 'San Miguel Premium 330ml', 'Beverages', 'Beer', '330ml', 32.00, 55.00),
    
    -- Nestle Products
    ('NESCAFE-3IN1', 'Nescafe 3-in-1 Original', 'Food & Beverage', 'Coffee', '20g', 8.50, 15.00),
    ('MAGGI-NOODLES', 'Maggi Chicken Noodles', 'Food & Beverage', 'Instant Food', '60g', 12.00, 22.00),
    ('MILO-POWDER', 'Milo Chocolate Powder 400g', 'Food & Beverage', 'Beverages', '400g', 145.00, 220.00),
    ('BEAR-BRAND', 'Bear Brand Milk 300ml', 'Food & Beverage', 'Dairy', '300ml', 28.00, 42.00),
    
    -- Unilever Products
    ('DOVE-SOAP', 'Dove Beauty Bar 100g', 'Personal Care', 'Bath & Body', '100g', 35.00, 65.00),
    ('CLEAR-SHAMPOO', 'Clear Shampoo 340ml', 'Personal Care', 'Hair Care', '340ml', 95.00, 165.00),
    ('CLOSEUP-PASTE', 'Closeup Toothpaste 160g', 'Personal Care', 'Oral Care', '160g', 55.00, 95.00),
    ('VASELINE-LOTION', 'Vaseline Body Lotion 400ml', 'Personal Care', 'Bath & Body', '400ml', 125.00, 185.00),
    
    -- P&G Products
    ('PANTENE-SHAMPOO', 'Pantene Shampoo 340ml', 'Personal Care', 'Hair Care', '340ml', 110.00, 175.00),
    ('OLAY-SOAP', 'Olay Beauty Bar 90g', 'Personal Care', 'Bath & Body', '90g', 42.00, 75.00),
    ('TIDE-POWDER', 'Tide Laundry Powder 1kg', 'Personal Care', 'Laundry', '1kg', 165.00, 245.00),
    
    -- Colgate Products
    ('COLGATE-PASTE', 'Colgate Total Toothpaste 150g', 'Personal Care', 'Oral Care', '150g', 58.00, 98.00),
    ('COLGATE-BRUSH', 'Colgate Toothbrush Medium', 'Personal Care', 'Oral Care', 'Single', 25.00, 45.00),
    ('PALMOLIVE-SOAP', 'Palmolive Soap 90g', 'Personal Care', 'Bath & Body', '90g', 18.00, 35.00)
) AS products_data(sku, name, category, subcategory, unit_size, unit_cost, retail_price)
WHERE (
    (b.name = 'San Miguel' AND products_data.sku LIKE 'SMB%') OR
    (b.name = 'Nestle' AND products_data.sku LIKE 'NESCAFE%' OR products_data.sku LIKE 'MAGGI%' OR products_data.sku LIKE 'MILO%' OR products_data.sku LIKE 'BEAR%') OR
    (b.name = 'Unilever' AND products_data.sku LIKE 'DOVE%' OR products_data.sku LIKE 'CLEAR%' OR products_data.sku LIKE 'CLOSEUP%' OR products_data.sku LIKE 'VASELINE%') OR
    (b.name = 'Procter & Gamble' AND products_data.sku LIKE 'PANTENE%' OR products_data.sku LIKE 'OLAY%' OR products_data.sku LIKE 'TIDE%') OR
    (b.name = 'Colgate-Palmolive' AND products_data.sku LIKE 'COLGATE%' OR products_data.sku LIKE 'PALMOLIVE%')
);

-- =============================================
-- STORES SEED DATA
-- =============================================

INSERT INTO public.stores (store_code, name, type, region, province, city, barangay, store_size) VALUES
-- NCR Stores
('STORE-NCR-001', 'Makati Sari-sari Store', 'Sari-sari Store', 'NCR', 'Metro Manila', 'Makati', 'Barangay San Lorenzo', 'Small'),
('STORE-NCR-002', 'QC Convenience Store', 'Convenience Store', 'NCR', 'Metro Manila', 'Quezon City', 'Barangay Diliman', 'Medium'),
('STORE-NCR-003', 'Manila Grocery', 'Grocery', 'NCR', 'Metro Manila', 'Manila', 'Barangay Ermita', 'Large'),
('STORE-NCR-004', 'Pasig Supermarket', 'Supermarket', 'NCR', 'Metro Manila', 'Pasig', 'Barangay Kapitolyo', 'Large'),
('STORE-NCR-005', 'Taguig Mini Mart', 'Convenience Store', 'NCR', 'Metro Manila', 'Taguig', 'Barangay BGC', 'Medium'),

-- Central Luzon Stores
('STORE-R03-001', 'Angeles Sari-sari', 'Sari-sari Store', 'R03', 'Pampanga', 'Angeles', 'Barangay Anunas', 'Small'),
('STORE-R03-002', 'San Fernando Grocery', 'Grocery', 'R03', 'Pampanga', 'San Fernando', 'Barangay Del Pilar', 'Medium'),
('STORE-R03-003', 'Cabanatuan Mart', 'Convenience Store', 'R03', 'Nueva Ecija', 'Cabanatuan', 'Barangay Centro', 'Medium'),
('STORE-R03-004', 'Olongapo Store', 'Grocery', 'R03', 'Zambales', 'Olongapo', 'Barangay Barretto', 'Large'),

-- Calabarzon Stores
('STORE-R04A-001', 'Calamba Sari-sari', 'Sari-sari Store', 'R04A', 'Laguna', 'Calamba', 'Barangay Real', 'Small'),
('STORE-R04A-002', 'Santa Rosa Mall', 'Supermarket', 'R04A', 'Laguna', 'Santa Rosa', 'Barangay Balibago', 'Large'),
('STORE-R04A-003', 'Antipolo Grocery', 'Grocery', 'R04A', 'Rizal', 'Antipolo', 'Barangay San Roque', 'Medium'),
('STORE-R04A-004', 'Batangas Store', 'Convenience Store', 'R04A', 'Batangas', 'Batangas City', 'Barangay Poblacion', 'Medium'),

-- Central Visayas Stores
('STORE-R07-001', 'Cebu Sari-sari', 'Sari-sari Store', 'R07', 'Cebu', 'Cebu City', 'Barangay Lahug', 'Small'),
('STORE-R07-002', 'Lapu-Lapu Mart', 'Convenience Store', 'R07', 'Cebu', 'Lapu-Lapu', 'Barangay Poblacion', 'Medium'),
('STORE-R07-003', 'Bohol Grocery', 'Grocery', 'R07', 'Bohol', 'Tagbilaran', 'Barangay Cogon', 'Medium'),

-- Davao Region Stores
('STORE-R11-001', 'Davao Supermarket', 'Supermarket', 'R11', 'Davao del Sur', 'Davao City', 'Barangay Poblacion', 'Large'),
('STORE-R11-002', 'Tagum Store', 'Grocery', 'R11', 'Davao del Norte', 'Tagum', 'Barangay Mankilam', 'Medium'),
('STORE-R11-003', 'Digos Sari-sari', 'Sari-sari Store', 'R11', 'Davao del Sur', 'Digos', 'Barangay Zone 1', 'Small');

-- =============================================
-- CUSTOMERS SEED DATA
-- =============================================

INSERT INTO public.customers (customer_code, gender, age_group, location_region, location_province, location_city, location_barangay, income_bracket, loyalty_tier) VALUES
-- NCR Customers
('CUST-000001', 'Female', '26-35', 'NCR', 'Metro Manila', 'Makati', 'Barangay San Lorenzo', 'High', 'Gold'),
('CUST-000002', 'Male', '36-45', 'NCR', 'Metro Manila', 'Quezon City', 'Barangay Diliman', 'Upper Middle', 'Silver'),
('CUST-000003', 'Female', '18-25', 'NCR', 'Metro Manila', 'Manila', 'Barangay Ermita', 'Middle', 'Bronze'),
('CUST-000004', 'Male', '46-55', 'NCR', 'Metro Manila', 'Pasig', 'Barangay Kapitolyo', 'High', 'Platinum'),
('CUST-000005', 'Female', '26-35', 'NCR', 'Metro Manila', 'Taguig', 'Barangay BGC', 'High', 'Gold'),

-- Regional Customers
('CUST-000006', 'Male', '36-45', 'R03', 'Pampanga', 'Angeles', 'Barangay Anunas', 'Middle', 'Silver'),
('CUST-000007', 'Female', '26-35', 'R03', 'Pampanga', 'San Fernando', 'Barangay Del Pilar', 'Upper Middle', 'Gold'),
('CUST-000008', 'Male', '18-25', 'R04A', 'Laguna', 'Calamba', 'Barangay Real', 'Middle', 'Bronze'),
('CUST-000009', 'Female', '46-55', 'R04A', 'Laguna', 'Santa Rosa', 'Barangay Balibago', 'High', 'Platinum'),
('CUST-000010', 'Male', '26-35', 'R07', 'Cebu', 'Cebu City', 'Barangay Lahug', 'Upper Middle', 'Silver'),
('CUST-000011', 'Female', '36-45', 'R11', 'Davao del Sur', 'Davao City', 'Barangay Poblacion', 'Middle', 'Gold'),
('CUST-000012', 'Male', '18-25', 'R11', 'Davao del Norte', 'Tagum', 'Barangay Mankilam', 'Middle', 'Bronze');

-- =============================================
-- SAMPLE TRANSACTIONS SEED DATA
-- =============================================

WITH sample_transactions AS (
    INSERT INTO public.transactions (
        transaction_code, customer_id, store_id, transaction_date, 
        total_amount, total_items, payment_method, discount_amount, tax_amount
    )
    SELECT 
        'TXN-SEED-' || LPAD(generate_series::text, 4, '0'),
        (SELECT id FROM public.customers ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM public.stores ORDER BY RANDOM() LIMIT 1),
        CURRENT_DATE - (RANDOM() * 30)::integer * INTERVAL '1 day',
        ROUND((RANDOM() * 500 + 50)::numeric, 2),
        FLOOR(RANDOM() * 5 + 1)::integer,
        (ARRAY['Cash', 'GCash', 'Credit Card', 'Debit Card'])[FLOOR(RANDOM() * 4 + 1)],
        ROUND((RANDOM() * 50)::numeric, 2),
        0
    FROM generate_series(1, 50)
    RETURNING id, total_amount, total_items
)
-- Add transaction items for each transaction
INSERT INTO public.transaction_items (transaction_id, product_id, quantity, unit_price, discount_amount)
SELECT 
    t.id,
    (SELECT id FROM public.products ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 3 + 1)::integer,
    ROUND((RANDOM() * 100 + 10)::numeric, 2),
    ROUND((RANDOM() * 10)::numeric, 2)
FROM sample_transactions t
CROSS JOIN generate_series(1, 2); -- 1-2 items per transaction

-- =============================================
-- DEVICES SEED DATA
-- =============================================

INSERT INTO public.devices (device_id, store_id, device_type, model, firmware_version, installation_date, last_maintenance)
SELECT 
    'DEV-' || s.store_code || '-' || LPAD(generate_series::text, 2, '0'),
    s.id,
    (ARRAY['POS Terminal', 'Kiosk', 'Scanner', 'Display'])[FLOOR(RANDOM() * 4 + 1)],
    'Model-' || (ARRAY['A100', 'B200', 'C300', 'D400'])[FLOOR(RANDOM() * 4 + 1)],
    'v' || FLOOR(RANDOM() * 5 + 1) || '.' || FLOOR(RANDOM() * 10) || '.' || FLOOR(RANDOM() * 10),
    CURRENT_DATE - (RANDOM() * 365)::integer * INTERVAL '1 day',
    CURRENT_DATE - (RANDOM() * 30)::integer * INTERVAL '1 day'
FROM public.stores s
CROSS JOIN generate_series(1, 2);

-- =============================================
-- SAMPLE DEVICE HEALTH DATA
-- =============================================

INSERT INTO public.device_health (device_id, store_id, status, cpu_usage, memory_usage, disk_usage, network_latency, error_count, uptime_hours)
SELECT 
    d.device_id,
    d.store_id,
    (ARRAY['online', 'online', 'online', 'offline', 'maintenance', 'error'])[FLOOR(RANDOM() * 6 + 1)],
    ROUND((RANDOM() * 85 + 10)::numeric, 2),
    ROUND((RANDOM() * 75 + 20)::numeric, 2),
    ROUND((RANDOM() * 80 + 15)::numeric, 2),
    FLOOR(RANDOM() * 150 + 10)::integer,
    FLOOR(RANDOM() * 5)::integer,
    ROUND((RANDOM() * 168)::numeric, 2)
FROM public.devices d;

-- =============================================
-- CLEAN UP AND VALIDATE
-- =============================================

-- Update transaction totals based on items
UPDATE public.transactions t
SET total_amount = COALESCE(calculated.item_total, 0),
    total_items = COALESCE(calculated.item_count, 0),
    tax_amount = ROUND(COALESCE(calculated.item_total, 0) * 0.12, 2)
FROM (
    SELECT 
        ti.transaction_id,
        SUM(ti.total_price - COALESCE(ti.discount_amount, 0)) as item_total,
        COUNT(*) as item_count
    FROM public.transaction_items ti
    GROUP BY ti.transaction_id
) calculated
WHERE t.id = calculated.transaction_id;

-- Create initial super admin user role (placeholder - will be updated with real user)
INSERT INTO public.user_roles (user_id, email, role, is_active) VALUES
(gen_random_uuid(), 'admin@scout-analytics.com', 'super_admin', true);

-- Refresh materialized views
SELECT public.refresh_analytical_views();

-- =============================================
-- VALIDATION QUERIES
-- =============================================

-- Verify data integrity
DO $$
DECLARE
    brand_count integer;
    product_count integer;
    store_count integer;
    customer_count integer;
    transaction_count integer;
BEGIN
    SELECT COUNT(*) INTO brand_count FROM public.brands;
    SELECT COUNT(*) INTO product_count FROM public.products;
    SELECT COUNT(*) INTO store_count FROM public.stores;
    SELECT COUNT(*) INTO customer_count FROM public.customers;
    SELECT COUNT(*) INTO transaction_count FROM public.transactions;
    
    RAISE NOTICE 'Seed data validation:';
    RAISE NOTICE 'Brands: %', brand_count;
    RAISE NOTICE 'Products: %', product_count;
    RAISE NOTICE 'Stores: %', store_count;
    RAISE NOTICE 'Customers: %', customer_count;
    RAISE NOTICE 'Transactions: %', transaction_count;
    
    IF brand_count < 10 OR product_count < 30 OR store_count < 15 OR customer_count < 10 OR transaction_count < 40 THEN
        RAISE EXCEPTION 'Seed data validation failed - insufficient records created';
    END IF;
    
    RAISE NOTICE 'Seed data validation passed successfully!';
END;
$$;-- =============================================
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
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all data changes';-- =============================================
-- Scout Analytics Dashboard - Analytical Views
-- Version: 1.0.0
-- Date: 2024-12-20
-- =============================================

-- =============================================
-- TRANSACTION TRENDS VIEW
-- =============================================

CREATE OR REPLACE VIEW vw_transaction_trends AS
SELECT 
    t.id,
    t.transaction_code,
    t.transaction_date,
    DATE_TRUNC('hour', t.transaction_date) as transaction_hour,
    DATE_TRUNC('day', t.transaction_date) as transaction_day,
    DATE_TRUNC('week', t.transaction_date) as transaction_week,
    DATE_TRUNC('month', t.transaction_date) as transaction_month,
    t.hour_of_day,
    t.is_weekend,
    CASE 
        WHEN t.hour_of_day BETWEEN 6 AND 11 THEN 'Morning'
        WHEN t.hour_of_day BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN t.hour_of_day BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END as time_period,
    t.total_amount,
    t.total_items,
    t.payment_method,
    t.discount_amount,
    t.tax_amount,
    s.region,
    s.province,
    s.city,
    s.barangay,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.location_region as customer_region,
    c.income_bracket as customer_income,
    c.loyalty_tier as customer_loyalty_tier,
    -- Calculated metrics
    (t.total_amount - t.discount_amount - t.tax_amount) as net_sales,
    (t.total_amount / NULLIF(t.total_items, 0)) as average_item_value,
    -- Time-based flags
    EXTRACT(DOW FROM t.transaction_date) as day_of_week,
    EXTRACT(MONTH FROM t.transaction_date) as month_number,
    EXTRACT(QUARTER FROM t.transaction_date) as quarter_number,
    EXTRACT(YEAR FROM t.transaction_date) as year_number
FROM transactions t
JOIN stores s ON t.store_id = s.id
LEFT JOIN customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years';

-- Index for performance
CREATE INDEX idx_vw_transaction_trends_date ON vw_transaction_trends(transaction_date);
CREATE INDEX idx_vw_transaction_trends_region_date ON vw_transaction_trends(region, transaction_date);

-- =============================================
-- PRODUCT MIX VIEW
-- =============================================

CREATE OR REPLACE VIEW vw_product_mix AS
SELECT 
    p.id as product_id,
    p.sku,
    p.name as product_name,
    p.category,
    p.subcategory,
    p.unit_size,
    p.unit_cost,
    p.retail_price,
    p.margin_percentage,
    b.id as brand_id,
    b.name as brand_name,
    b.category as brand_category,
    b.manufacturer,
    b.country_origin,
    ti.transaction_id,
    ti.quantity,
    ti.unit_price,
    ti.total_price,
    ti.discount_amount as item_discount,
    t.transaction_date,
    t.total_amount as transaction_total,
    s.region,
    s.province,
    s.city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    -- Calculated metrics
    (ti.total_price - ti.discount_amount) as net_item_revenue,
    (ti.quantity * p.unit_cost) as item_cost,
    ((ti.total_price - ti.discount_amount) - (ti.quantity * p.unit_cost)) as item_profit,
    CASE 
        WHEN (ti.quantity * p.unit_cost) > 0 
        THEN (((ti.total_price - ti.discount_amount) - (ti.quantity * p.unit_cost)) / (ti.quantity * p.unit_cost)) * 100
        ELSE 0
    END as item_margin_percentage,
    -- Market share calculations (requires window functions in queries)
    ti.total_price / t.total_amount * 100 as transaction_share_percentage
FROM transaction_items ti
JOIN transactions t ON ti.transaction_id = t.id
JOIN products p ON ti.product_id = p.id
JOIN brands b ON p.brand_id = b.id
JOIN stores s ON t.store_id = s.id
LEFT JOIN customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
  AND p.is_active = true
  AND b.is_active = true;

-- Index for performance
CREATE INDEX idx_vw_product_mix_category_date ON vw_product_mix(category, transaction_date);
CREATE INDEX idx_vw_product_mix_brand_date ON vw_product_mix(brand_name, transaction_date);

-- =============================================
-- SUBSTITUTIONS VIEW
-- =============================================

CREATE OR REPLACE VIEW vw_substitutions AS
SELECT 
    sub.id as substitution_id,
    sub.transaction_id,
    sub.was_accepted,
    sub.reason,
    sub.customer_satisfaction_score,
    t.transaction_date,
    t.total_amount as transaction_total,
    -- Original product details
    p_orig.id as original_product_id,
    p_orig.sku as original_sku,
    p_orig.name as original_product_name,
    p_orig.category as original_category,
    p_orig.subcategory as original_subcategory,
    p_orig.retail_price as original_price,
    b_orig.name as original_brand_name,
    -- Substitute product details
    p_sub.id as substitute_product_id,
    p_sub.sku as substitute_sku,
    p_sub.name as substitute_product_name,
    p_sub.category as substitute_category,
    p_sub.subcategory as substitute_subcategory,
    p_sub.retail_price as substitute_price,
    b_sub.name as substitute_brand_name,
    -- Price comparison
    (p_sub.retail_price - p_orig.retail_price) as price_difference,
    CASE 
        WHEN p_orig.retail_price > 0 
        THEN ((p_sub.retail_price - p_orig.retail_price) / p_orig.retail_price) * 100
        ELSE 0
    END as price_difference_percentage,
    -- Store and customer info
    s.region,
    s.province,
    s.city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.loyalty_tier as customer_loyalty_tier,
    -- Categorization
    CASE 
        WHEN p_orig.category = p_sub.category THEN 'Same Category'
        ELSE 'Cross Category'
    END as substitution_type,
    CASE 
        WHEN b_orig.name = b_sub.name THEN 'Same Brand'
        ELSE 'Brand Switch'
    END as brand_substitution_type
FROM substitutions sub
JOIN transactions t ON sub.transaction_id = t.id
JOIN products p_orig ON sub.original_product_id = p_orig.id
JOIN products p_sub ON sub.substitute_product_id = p_sub.id
JOIN brands b_orig ON p_orig.brand_id = b_orig.id
JOIN brands b_sub ON p_sub.brand_id = b_sub.id
JOIN stores s ON t.store_id = s.id
LEFT JOIN customers c ON t.customer_id = c.id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years';

-- Index for performance
CREATE INDEX idx_vw_substitutions_date ON vw_substitutions(transaction_date);
CREATE INDEX idx_vw_substitutions_acceptance ON vw_substitutions(was_accepted);

-- =============================================
-- CONSUMER BEHAVIOR VIEW
-- =============================================

CREATE OR REPLACE VIEW vw_consumer_behavior AS
SELECT 
    rb.id as behavior_id,
    rb.customer_id,
    rb.request_type,
    rb.request_category,
    rb.request_details,
    rb.response_time_ms,
    rb.was_successful,
    rb.timestamp as behavior_timestamp,
    DATE_TRUNC('hour', rb.timestamp) as behavior_hour,
    DATE_TRUNC('day', rb.timestamp) as behavior_day,
    EXTRACT(HOUR FROM rb.timestamp) as hour_of_day,
    EXTRACT(DOW FROM rb.timestamp) as day_of_week,
    CASE 
        WHEN EXTRACT(DOW FROM rb.timestamp) IN (0, 6) THEN true
        ELSE false
    END as is_weekend,
    -- Customer details
    c.gender as customer_gender,
    c.age_group as customer_age_group,
    c.location_region as customer_region,
    c.location_province as customer_province,
    c.location_city as customer_city,
    c.income_bracket as customer_income,
    c.loyalty_tier as customer_loyalty_tier,
    -- Store details
    s.region as store_region,
    s.province as store_province,
    s.city as store_city,
    s.store_code,
    s.name as store_name,
    s.type as store_type,
    -- Performance metrics
    CASE 
        WHEN rb.response_time_ms <= 1000 THEN 'Fast'
        WHEN rb.response_time_ms <= 3000 THEN 'Medium'
        ELSE 'Slow'
    END as response_speed_category,
    -- Request patterns
    CASE 
        WHEN rb.request_type LIKE '%product%' THEN 'Product Related'
        WHEN rb.request_type LIKE '%price%' THEN 'Price Related'
        WHEN rb.request_type LIKE '%location%' THEN 'Location Related'
        ELSE 'Other'
    END as request_pattern
FROM request_behaviors rb
JOIN stores s ON rb.store_id = s.id
LEFT JOIN customers c ON rb.customer_id = c.id
WHERE rb.timestamp >= CURRENT_DATE - INTERVAL '1 year';

-- Index for performance
CREATE INDEX idx_vw_consumer_behavior_timestamp ON vw_consumer_behavior(behavior_timestamp);
CREATE INDEX idx_vw_consumer_behavior_customer ON vw_consumer_behavior(customer_id);

-- =============================================
-- CONSUMER PROFILE VIEW
-- =============================================

CREATE OR REPLACE VIEW vw_consumer_profile AS
WITH customer_transaction_summary AS (
    SELECT 
        c.id as customer_id,
        COUNT(t.id) as total_transactions,
        SUM(t.total_amount) as total_spent,
        AVG(t.total_amount) as avg_transaction_value,
        SUM(t.total_items) as total_items_purchased,
        MIN(t.transaction_date) as first_transaction_date,
        MAX(t.transaction_date) as last_transaction_date,
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) as active_months,
        COUNT(DISTINCT t.store_id) as stores_visited
    FROM customers c
    LEFT JOIN transactions t ON c.id = t.customer_id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.id
),
customer_preferences AS (
    SELECT 
        c.id as customer_id,
        MODE() WITHIN GROUP (ORDER BY p.category) as preferred_category,
        MODE() WITHIN GROUP (ORDER BY b.name) as preferred_brand,
        MODE() WITHIN GROUP (ORDER BY s.type) as preferred_store_type,
        COUNT(DISTINCT p.category) as categories_purchased,
        COUNT(DISTINCT b.name) as brands_purchased
    FROM customers c
    JOIN transactions t ON c.id = t.customer_id
    JOIN transaction_items ti ON t.id = ti.transaction_id
    JOIN products p ON ti.product_id = p.id
    JOIN brands b ON p.brand_id = b.id
    JOIN stores s ON t.store_id = s.id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '2 years'
    GROUP BY c.id
)
SELECT 
    c.id as customer_id,
    c.customer_code,
    c.gender,
    c.age_group,
    c.location_region,
    c.location_province,
    c.location_city,
    c.location_barangay,
    c.income_bracket,
    c.loyalty_tier,
    c.created_at as customer_since,
    -- Transaction metrics
    COALESCE(cts.total_transactions, 0) as total_transactions,
    COALESCE(cts.total_spent, 0) as total_spent,
    COALESCE(cts.avg_transaction_value, 0) as avg_transaction_value,
    COALESCE(cts.total_items_purchased, 0) as total_items_purchased,
    cts.first_transaction_date,
    cts.last_transaction_date,
    COALESCE(cts.active_months, 0) as active_months,
    COALESCE(cts.stores_visited, 0) as stores_visited,
    -- Preferences
    cp.preferred_category,
    cp.preferred_brand,
    cp.preferred_store_type,
    COALESCE(cp.categories_purchased, 0) as categories_purchased,
    COALESCE(cp.brands_purchased, 0) as brands_purchased,
    -- Calculated segments
    CASE 
        WHEN cts.total_spent >= 50000 THEN 'High Value'
        WHEN cts.total_spent >= 20000 THEN 'Medium Value'
        WHEN cts.total_spent >= 5000 THEN 'Low Value'
        ELSE 'New/Inactive'
    END as value_segment,
    CASE 
        WHEN cts.total_transactions >= 50 THEN 'High Frequency'
        WHEN cts.total_transactions >= 20 THEN 'Medium Frequency'
        WHEN cts.total_transactions >= 5 THEN 'Low Frequency'
        ELSE 'New/Inactive'
    END as frequency_segment,
    -- Recency (days since last transaction)
    CASE 
        WHEN cts.last_transaction_date IS NULL THEN NULL
        ELSE CURRENT_DATE - cts.last_transaction_date::DATE
    END as days_since_last_transaction,
    -- Customer lifetime metrics
    CASE 
        WHEN cts.first_transaction_date IS NOT NULL AND cts.last_transaction_date IS NOT NULL 
        THEN cts.last_transaction_date::DATE - cts.first_transaction_date::DATE + 1
        ELSE NULL
    END as customer_lifetime_days
FROM customers c
LEFT JOIN customer_transaction_summary cts ON c.id = cts.customer_id
LEFT JOIN customer_preferences cp ON c.id = cp.customer_id
WHERE c.is_active = true;

-- Index for performance
CREATE INDEX idx_vw_consumer_profile_segments ON vw_consumer_profile(value_segment, frequency_segment);
CREATE INDEX idx_vw_consumer_profile_location ON vw_consumer_profile(location_region, location_province);

-- =============================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- =============================================

-- Daily transaction summary (materialized for better performance)
CREATE MATERIALIZED VIEW mv_daily_transaction_summary AS
SELECT 
    DATE_TRUNC('day', transaction_date) as transaction_day,
    region,
    province,
    city,
    store_type,
    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    SUM(total_items) as total_items_sold,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT store_id) as active_stores
FROM vw_transaction_trends
GROUP BY 
    DATE_TRUNC('day', transaction_date),
    region,
    province,
    city,
    store_type;

-- Create unique index for refresh
CREATE UNIQUE INDEX idx_mv_daily_summary_unique 
ON mv_daily_transaction_summary(transaction_day, region, province, city, store_type);

-- Product performance summary (materialized)
CREATE MATERIALIZED VIEW mv_product_performance_summary AS
SELECT 
    category,
    subcategory,
    brand_name,
    product_name,
    sku,
    DATE_TRUNC('month', transaction_date) as month,
    SUM(quantity) as total_quantity_sold,
    SUM(net_item_revenue) as total_revenue,
    AVG(item_margin_percentage) as avg_margin,
    COUNT(DISTINCT transaction_id) as transaction_count,
    COUNT(DISTINCT customer_id) as unique_customers
FROM vw_product_mix
GROUP BY 
    category,
    subcategory,
    brand_name,
    product_name,
    sku,
    DATE_TRUNC('month', transaction_date);

-- Create unique index for refresh
CREATE UNIQUE INDEX idx_mv_product_performance_unique 
ON mv_product_performance_summary(category, subcategory, brand_name, product_name, sku, month);

-- =============================================
-- REFRESH FUNCTIONS FOR MATERIALIZED VIEWS
-- =============================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_analytical_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_transaction_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_performance_summary;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON VIEW vw_transaction_trends IS 'Comprehensive transaction analysis with time-based segmentation and geographic breakdowns';
COMMENT ON VIEW vw_product_mix IS 'Detailed product performance metrics with profitability calculations';
COMMENT ON VIEW vw_substitutions IS 'Product substitution patterns and acceptance analysis';
COMMENT ON VIEW vw_consumer_behavior IS 'Customer interaction patterns and request behavior analysis';
COMMENT ON VIEW vw_consumer_profile IS 'Complete customer profiling with RFM analysis and preferences';
COMMENT ON MATERIALIZED VIEW mv_daily_transaction_summary IS 'Pre-aggregated daily metrics for dashboard performance';
COMMENT ON MATERIALIZED VIEW mv_product_performance_summary IS 'Pre-aggregated monthly product performance metrics';-- =============================================
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