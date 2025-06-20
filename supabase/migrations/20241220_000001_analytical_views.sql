-- =============================================
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
COMMENT ON MATERIALIZED VIEW mv_product_performance_summary IS 'Pre-aggregated monthly product performance metrics';