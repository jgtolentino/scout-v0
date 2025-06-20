-- =============================================
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
COMMENT ON FUNCTION public.archive_old_data() IS 'Archives old data to maintain database performance - run periodically';