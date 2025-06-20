#!/bin/bash

# =============================================
# Scout Analytics Dashboard - Database Setup Script
# Description: Automated setup and teardown for Scout Analytics database
# =============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DB_NAME="scout_analytics"
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
MIGRATIONS_DIR="supabase/migrations"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v supabase &> /dev/null; then
        log_error "Supabase CLI not found. Please install it first:"
        echo "npm install -g supabase"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js first."
        exit 1
    fi
    
    log_success "All dependencies found"
}

check_supabase_auth() {
    log_info "Checking Supabase authentication..."
    
    if ! supabase status &> /dev/null; then
        log_error "Not logged into Supabase. Please run 'supabase login' first."
        exit 1
    fi
    
    log_success "Supabase authentication verified"
}

init_project() {
    log_info "Initializing Supabase project..."
    
    if [ ! -f "supabase/config.toml" ]; then
        supabase init
        log_success "Supabase project initialized"
    else
        log_info "Supabase project already initialized"
    fi
}

start_local_db() {
    log_info "Starting local Supabase database..."
    
    supabase start
    log_success "Local database started"
}

stop_local_db() {
    log_info "Stopping local Supabase database..."
    
    supabase stop
    log_success "Local database stopped"
}

run_migrations() {
    log_info "Running database migrations..."
    
    if [ ! -d "$MIGRATIONS_DIR" ]; then
        log_error "Migrations directory not found: $MIGRATIONS_DIR"
        exit 1
    fi
    
    # Count migration files
    migration_count=$(find "$MIGRATIONS_DIR" -name "*.sql" | wc -l)
    log_info "Found $migration_count migration files"
    
    # Run migrations
    supabase db push
    log_success "Migrations completed successfully"
}

generate_types() {
    log_info "Generating TypeScript types..."
    
    supabase gen types typescript --local > src/types/database.ts
    log_success "TypeScript types generated"
}

seed_database() {
    log_info "Seeding database with sample data..."
    
    # The seed data is included in migration 007_seed_data.sql
    # so it runs automatically with migrations
    log_success "Database seeded with sample data"
}

run_mock_data_generator() {
    log_info "Generating additional mock data..."
    
    if [ ! -f "scripts/generateMockTransactions.js" ]; then
        log_error "Mock data generator not found"
        exit 1
    fi
    
    # Generate 1000 additional transactions
    node scripts/generateMockTransactions.js --count 1000 --output data/additional_transactions.json
    log_success "Additional mock data generated"
}

validate_setup() {
    log_info "Validating database setup..."
    
    # Test database connection and basic queries
    local validation_sql="
    SELECT 
        (SELECT COUNT(*) FROM public.brands) as brands,
        (SELECT COUNT(*) FROM public.products) as products,
        (SELECT COUNT(*) FROM public.stores) as stores,
        (SELECT COUNT(*) FROM public.customers) as customers,
        (SELECT COUNT(*) FROM public.transactions) as transactions;
    "
    
    echo "$validation_sql" | supabase db query
    
    log_success "Database validation completed"
}

show_usage() {
    echo "Scout Analytics Database Setup Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  setup           Full setup (init, start, migrate, seed, validate)"
    echo "  start           Start local database"
    echo "  stop            Stop local database"
    echo "  migrate         Run database migrations"
    echo "  seed            Seed database with sample data"
    echo "  mock            Generate additional mock data"
    echo "  types           Generate TypeScript types"
    echo "  validate        Validate database setup"
    echo "  reset           Reset database (stop, start, migrate, seed)"
    echo "  teardown        Stop and remove local database"
    echo "  help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  SUPABASE_PROJECT_REF    Supabase project reference (for remote operations)"
    echo ""
    echo "Examples:"
    echo "  $0 setup                    # Full local setup"
    echo "  $0 migrate                  # Run migrations only"
    echo "  $0 reset                    # Reset and reseed database"
}

setup_full() {
    log_info "Starting full Scout Analytics database setup..."
    
    check_dependencies
    check_supabase_auth
    init_project
    start_local_db
    run_migrations
    seed_database
    generate_types
    validate_setup
    
    log_success "Database setup completed successfully!"
    log_info "Your Scout Analytics dashboard is ready to use."
    log_info "Local Supabase URL: http://localhost:54321"
    log_info "Local Studio URL: http://localhost:54323"
}

reset_database() {
    log_info "Resetting Scout Analytics database..."
    
    stop_local_db
    start_local_db
    run_migrations
    seed_database
    generate_types
    validate_setup
    
    log_success "Database reset completed!"
}

teardown() {
    log_info "Tearing down Scout Analytics database..."
    
    supabase stop --no-backup
    
    log_success "Database teardown completed"
}

# Main script logic
case "${1:-}" in
    "setup")
        setup_full
        ;;
    "start")
        check_dependencies
        start_local_db
        ;;
    "stop")
        check_dependencies
        stop_local_db
        ;;
    "migrate")
        check_dependencies
        run_migrations
        ;;
    "seed")
        check_dependencies
        seed_database
        ;;
    "mock")
        check_dependencies
        run_mock_data_generator
        ;;
    "types")
        check_dependencies
        generate_types
        ;;
    "validate")
        check_dependencies
        validate_setup
        ;;
    "reset")
        check_dependencies
        reset_database
        ;;
    "teardown")
        check_dependencies
        teardown
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    "")
        log_error "No command specified"
        show_usage
        exit 1
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac