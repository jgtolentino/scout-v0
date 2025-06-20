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
COMMENT ON TABLE public.customer_requests IS 'Specific customer requests and fulfillment tracking';