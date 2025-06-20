-- =============================================
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
$$;