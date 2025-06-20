-- =============================================
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
COMMENT ON FUNCTION public.get_data_summary() IS 'Returns comprehensive summary of dataset for verification and reporting';