#!/bin/bash

# =============================================
# Scout Analytics Dashboard - Immediate Deployment
# Description: Docker-free deployment for immediate use
# =============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Step 1: Environment Setup
setup_environment() {
    log_info "Setting up environment configuration..."
    
    if [ ! -f ".env.local" ]; then
        cp .env.example .env.local
        log_success "Created .env.local from template"
        log_warning "Please update .env.local with your Supabase credentials"
    else
        log_info ".env.local already exists"
    fi
}

# Step 2: Install Dependencies
install_dependencies() {
    log_info "Installing project dependencies..."
    
    if [ ! -d "node_modules" ]; then
        npm install
        log_success "Dependencies installed"
    else
        log_info "Dependencies already installed"
    fi
}

# Step 3: Build Project
build_project() {
    log_info "Building project for production..."
    
    npm run build
    log_success "Project built successfully"
}

# Step 4: Create Deployment Package
create_deployment_package() {
    log_info "Creating deployment package..."
    
    # Create deployment directory
    mkdir -p deploy/scout-analytics
    
    # Copy essential files
    cp -r dist deploy/scout-analytics/
    cp -r supabase deploy/scout-analytics/
    cp -r scripts deploy/scout-analytics/
    cp package.json deploy/scout-analytics/
    cp README.md deploy/scout-analytics/
    cp .env.example deploy/scout-analytics/
    
    # Create deployment README
    cat > deploy/scout-analytics/DEPLOY.md << 'EOF'
# Scout Analytics Dashboard - Deployment Package

## Quick Deploy to Vercel

1. **Upload to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial Scout Analytics deployment"
   git remote add origin https://github.com/your-username/scout-analytics.git
   git push -u origin main
   ```

2. **Deploy to Vercel:**
   - Visit: https://vercel.com/new
   - Import your GitHub repository
   - Configure environment variables from .env.example
   - Deploy

3. **Set up Supabase:**
   - Create project at https://supabase.com/dashboard
   - Run migrations: `supabase db push`
   - Update environment variables with your Supabase URLs

## Quick Deploy to Azure Static Web Apps

1. **Create Azure Static Web App:**
   - Visit Azure Portal
   - Create new Static Web App
   - Connect to your GitHub repository

2. **Configure Build:**
   - Build command: `npm run build`
   - Output directory: `dist`

## Environment Variables Required

```bash
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Database Setup

1. **Create Supabase project**
2. **Run migrations:**
   ```bash
   supabase link --project-ref your-project-ref
   supabase db push
   ```
3. **Verify setup:**
   ```bash
   supabase db query "SELECT COUNT(*) FROM brands;"
   ```

Your Scout Analytics Dashboard is ready for production!
EOF
    
    # Create Vercel config
    cat > deploy/scout-analytics/vercel.json << 'EOF'
{
  "version": 2,
  "builds": [
    {
      "src": "dist/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/dist/$1"
    }
  ],
  "env": {
    "NEXT_PUBLIC_SUPABASE_URL": "@supabase-url",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY": "@supabase-anon-key",
    "SUPABASE_SERVICE_ROLE_KEY": "@supabase-service-role-key"
  }
}
EOF
    
    log_success "Deployment package created in deploy/scout-analytics/"
}

# Step 5: Generate SQL Export
generate_sql_export() {
    log_info "Generating SQL export for manual database setup..."
    
    cat supabase/migrations/*.sql > deploy/scout-analytics/complete_schema.sql
    
    cat > deploy/scout-analytics/manual_db_setup.sql << 'EOF'
-- =============================================
-- Scout Analytics Dashboard - Manual DB Setup
-- Run this on any PostgreSQL database
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Include all migrations
EOF
    
    cat supabase/migrations/*.sql >> deploy/scout-analytics/manual_db_setup.sql
    
    log_success "SQL export created: deploy/scout-analytics/manual_db_setup.sql"
}

# Step 6: Validate Build
validate_build() {
    log_info "Validating build..."
    
    if [ -d "dist" ] && [ -f "dist/index.html" ]; then
        log_success "Build validation passed"
        
        # Check file sizes
        build_size=$(du -sh dist | cut -f1)
        log_info "Build size: $build_size"
        
        # Check for critical files
        if [ -f "dist/assets/index.js" ] || [ -f "dist/assets/index.*.js" ]; then
            log_success "JavaScript assets found"
        fi
        
        if [ -f "dist/assets/index.css" ] || [ -f "dist/assets/index.*.css" ]; then
            log_success "CSS assets found"
        fi
        
    else
        log_error "Build validation failed - dist directory missing or incomplete"
        exit 1
    fi
}

# Main deployment function
deploy_immediate() {
    log_info "🚀 Starting immediate deployment preparation..."
    
    setup_environment
    install_dependencies
    build_project
    validate_build
    create_deployment_package
    generate_sql_export
    
    log_success "🎉 Deployment package ready!"
    echo ""
    echo "📦 Deployment files created in: deploy/scout-analytics/"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Upload deploy/scout-analytics/ to your hosting provider"
    echo "2. Set up Supabase database using manual_db_setup.sql"
    echo "3. Configure environment variables"
    echo "4. Go live!"
    echo ""
    echo "📋 Quick deploy options:"
    echo "  • Vercel: Upload to GitHub → Import to Vercel"
    echo "  • Azure: Create Static Web App → Connect repository"
    echo "  • Netlify: Drag & drop dist/ folder"
    echo ""
    echo "📖 See deploy/scout-analytics/DEPLOY.md for detailed instructions"
}

# Execute deployment
deploy_immediate