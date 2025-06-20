#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';
import { faker } from '@faker-js/faker';

// Database configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'your-supabase-url';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'your-service-key';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Constants for data generation
const PHILIPPINE_REGIONS = [
    'National Capital Region', 'Cordillera Administrative Region', 'Ilocos Region',
    'Cagayan Valley', 'Central Luzon', 'Calabarzon', 'Mimaropa',
    'Bicol Region', 'Western Visayas', 'Central Visayas', 'Eastern Visayas',
    'Zamboanga Peninsula', 'Northern Mindanao', 'Davao Region', 'Soccsksargen',
    'Caraga', 'Barmm'
];

const FMCG_CATEGORIES = [
    'Beverages', 'Snacks', 'Personal Care', 'Household Care', 'Health & Wellness',
    'Baby Care', 'Food & Cooking', 'Dairy Products', 'Frozen Foods', 'Bakery'
];

const STORE_TYPES = ['Grocery', 'Convenience', 'Supermarket', 'Hypermarket', 'Sari-sari Store'];

const PAYMENT_METHODS = ['Cash', 'GCash', 'Credit Card', 'Debit Card', 'Maya', 'Bank Transfer'];

// Data generation utilities
const getRandomElement = (array) => array[Math.floor(Math.random() * array.length)];
const getRandomNumber = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const getRandomDecimal = (min, max, decimals = 2) => 
    parseFloat((Math.random() * (max - min) + min).toFixed(decimals));

// Generate realistic Philippine names and locations
const generatePhilippineCustomer = () => {
    const region = getRandomElement(PHILIPPINE_REGIONS);
    const provinces = {
        'National Capital Region': ['Metro Manila'],
        'Central Luzon': ['Bulacan', 'Nueva Ecija', 'Pampanga', 'Tarlac', 'Zambales'],
        'Calabarzon': ['Batangas', 'Cavite', 'Laguna', 'Quezon', 'Rizal'],
        'Western Visayas': ['Aklan', 'Antique', 'Capiz', 'Iloilo', 'Negros Occidental'],
        'Central Visayas': ['Bohol', 'Cebu', 'Negros Oriental', 'Siquijor'],
        'Davao Region': ['Davao del Norte', 'Davao del Sur', 'Davao Oriental']
    };
    
    const regionProvinces = provinces[region] || ['Sample Province'];
    const province = getRandomElement(regionProvinces);
    
    return {
        customer_code: `CUST-${faker.string.alphanumeric(8).toUpperCase()}`,
        gender: getRandomElement(['Male', 'Female']),
        age_group: getRandomElement(['18-25', '26-35', '36-45', '46-55', '56-65', '65+']),
        location_region: region,
        location_province: province,
        location_city: faker.location.city(),
        location_barangay: `Barangay ${faker.location.streetName()}`,
        income_bracket: getRandomElement(['Low', 'Middle', 'Upper Middle', 'High']),
        loyalty_tier: getRandomElement(['Bronze', 'Silver', 'Gold', 'Platinum'])
    };
};

class SeedDataGenerator {
    constructor() {
        this.brands = [];
        this.products = [];
        this.customers = [];
        this.stores = [];
        this.transactions = [];
        this.transactionItems = [];
        this.deviceHealthRecords = [];
        this.devices = [];
        this.substitutions = [];
        this.requestBehaviors = [];
        this.customerRequests = [];
        this.edgeLogs = [];
    }

    async generateBrands(count = 50) {
        console.log(`🏭 Generating ${count} brands...`);
        
        const brands = [];
        const realBrands = [
            { name: 'Coca-Cola', category: 'Beverages', manufacturer: 'The Coca-Cola Company', country: 'USA' },
            { name: 'Pepsi', category: 'Beverages', manufacturer: 'PepsiCo', country: 'USA' },
            { name: 'Nestlé', category: 'Food & Cooking', manufacturer: 'Nestlé S.A.', country: 'Switzerland' },
            { name: 'Unilever', category: 'Personal Care', manufacturer: 'Unilever PLC', country: 'Netherlands' },
            { name: 'Procter & Gamble', category: 'Household Care', manufacturer: 'P&G', country: 'USA' },
            { name: 'San Miguel', category: 'Beverages', manufacturer: 'San Miguel Corporation', country: 'Philippines' },
            { name: 'Jollibee', category: 'Food & Cooking', manufacturer: 'Jollibee Foods Corporation', country: 'Philippines' },
            { name: 'CDO', category: 'Food & Cooking', manufacturer: 'CDO Foodsphere Corporation', country: 'Philippines' }
        ];

        for (let i = 0; i < count; i++) {
            if (i < realBrands.length) {
                brands.push(realBrands[i]);
            } else {
                brands.push({
                    name: `${faker.company.name()} ${getRandomElement(['Corp', 'Inc', 'Ltd', 'Co'])}`,
                    category: getRandomElement(FMCG_CATEGORIES),
                    manufacturer: faker.company.name(),
                    country_origin: getRandomElement(['Philippines', 'USA', 'Japan', 'Singapore', 'Malaysia'])
                });
            }
        }

        const { data, error } = await supabase.from('brands').insert(brands).select();
        if (error) throw error;
        
        this.brands = data;
        console.log(`✅ Generated ${data.length} brands`);
    }

    async generateProducts(count = 500) {
        console.log(`📦 Generating ${count} products...`);
        
        const products = [];
        
        for (let i = 0; i < count; i++) {
            const brand = getRandomElement(this.brands);
            const unitCost = getRandomDecimal(5, 200);
            const markup = getRandomDecimal(1.2, 3.0);
            
            products.push({
                brand_id: brand.id,
                sku: `SKU-${faker.string.alphanumeric(10).toUpperCase()}`,
                name: `${brand.name} ${faker.commerce.productName()}`,
                category: brand.category,
                subcategory: faker.commerce.department(),
                unit_size: getRandomElement(['50g', '100g', '250ml', '500ml', '1L', '1kg', '250g']),
                unit_cost: unitCost,
                retail_price: parseFloat((unitCost * markup).toFixed(2))
            });
        }

        const { data, error } = await supabase.from('products').insert(products).select();
        if (error) throw error;
        
        this.products = data;
        console.log(`✅ Generated ${data.length} products`);
    }

    async generateCustomers(count = 2000) {
        console.log(`👥 Generating ${count} customers...`);
        
        const customers = [];
        
        for (let i = 0; i < count; i++) {
            customers.push(generatePhilippineCustomer());
        }

        const { data, error } = await supabase.from('customers').insert(customers).select();
        if (error) throw error;
        
        this.customers = data;
        console.log(`✅ Generated ${data.length} customers`);
    }

    async generateStores(count = 100) {
        console.log(`🏪 Generating ${count} stores...`);
        
        const stores = [];
        
        for (let i = 0; i < count; i++) {
            const region = getRandomElement(PHILIPPINE_REGIONS);
            
            stores.push({
                store_code: `STORE-${faker.string.alphanumeric(6).toUpperCase()}`,
                name: `${faker.company.name()} ${getRandomElement(STORE_TYPES)}`,
                type: getRandomElement(STORE_TYPES),
                region: region,
                province: faker.location.state(),
                city: faker.location.city(),
                barangay: `Barangay ${faker.location.streetName()}`,
                address: faker.location.streetAddress(),
                store_size: getRandomElement(['Small', 'Medium', 'Large'])
            });
        }

        const { data, error } = await supabase.from('stores').insert(stores).select();
        if (error) throw error;
        
        this.stores = data;
        console.log(`✅ Generated ${data.length} stores`);
    }

    async generateDevices() {
        console.log(`💻 Generating devices for stores...`);
        
        const devices = [];
        
        for (const store of this.stores) {
            const deviceCount = getRandomNumber(1, 3);
            
            for (let i = 0; i < deviceCount; i++) {
                devices.push({
                    device_id: `DEV-${store.store_code}-${String(i + 1).padStart(2, '0')}`,
                    store_id: store.id,
                    device_type: getRandomElement(['POS Terminal', 'Kiosk', 'Scanner', 'Display']),
                    model: `Model-${getRandomElement(['A100', 'B200', 'C300', 'D400'])}`,
                    firmware_version: `v${getRandomNumber(1, 5)}.${getRandomNumber(0, 9)}.${getRandomNumber(0, 9)}`,
                    installation_date: faker.date.past({ years: 2 }),
                    last_maintenance: faker.date.recent({ days: 30 })
                });
            }
        }

        const { data, error } = await supabase.from('devices').insert(devices).select();
        if (error) throw error;
        
        this.devices = data;
        console.log(`✅ Generated ${data.length} devices`);
    }

    async generateTransactions(count = 18000) {
        console.log(`💳 Generating ${count} transactions...`);
        
        const transactions = [];
        const batchSize = 1000;
        
        for (let batch = 0; batch < Math.ceil(count / batchSize); batch++) {
            const batchTransactions = [];
            const batchStart = batch * batchSize;
            const batchEnd = Math.min(batchStart + batchSize, count);
            
            for (let i = batchStart; i < batchEnd; i++) {
                const store = getRandomElement(this.stores);
                const customer = Math.random() > 0.1 ? getRandomElement(this.customers) : null;
                const transactionDate = faker.date.recent({ days: 365 });
                const totalItems = getRandomNumber(1, 15);
                const totalAmount = getRandomDecimal(50, 2000);
                
                batchTransactions.push({
                    transaction_code: `TXN-${faker.string.alphanumeric(12).toUpperCase()}`,
                    customer_id: customer?.id || null,
                    store_id: store.id,
                    transaction_date: transactionDate,
                    total_amount: totalAmount,
                    total_items: totalItems,
                    payment_method: getRandomElement(PAYMENT_METHODS),
                    discount_amount: getRandomDecimal(0, totalAmount * 0.2),
                    tax_amount: parseFloat((totalAmount * 0.12).toFixed(2))
                });
            }

            const { data, error } = await supabase.from('transactions').insert(batchTransactions).select();
            if (error) throw error;
            
            this.transactions.push(...data);
            console.log(`   📊 Batch ${batch + 1}/${Math.ceil(count / batchSize)} completed (${data.length} transactions)`);
        }
        
        console.log(`✅ Generated ${this.transactions.length} total transactions`);
    }

    async generateTransactionItems() {
        console.log(`🛒 Generating transaction items...`);
        
        const transactionItems = [];
        const batchSize = 2000;
        
        for (let batch = 0; batch < Math.ceil(this.transactions.length / batchSize); batch++) {
            const batchItems = [];
            const batchStart = batch * batchSize;
            const batchEnd = Math.min(batchStart + batchSize, this.transactions.length);
            
            for (let i = batchStart; i < batchEnd; i++) {
                const transaction = this.transactions[i];
                const itemCount = Math.min(transaction.total_items, 10);
                
                for (let j = 0; j < itemCount; j++) {
                    const product = getRandomElement(this.products);
                    const quantity = getRandomNumber(1, 5);
                    const unitPrice = getRandomDecimal(product.retail_price * 0.9, product.retail_price * 1.1);
                    
                    batchItems.push({
                        transaction_id: transaction.id,
                        product_id: product.id,
                        quantity: quantity,
                        unit_price: unitPrice,
                        discount_amount: getRandomDecimal(0, unitPrice * quantity * 0.1)
                    });
                }
            }

            const { data, error } = await supabase.from('transaction_items').insert(batchItems).select();
            if (error) throw error;
            
            this.transactionItems.push(...data);
            console.log(`   📊 Batch ${batch + 1}/${Math.ceil(this.transactions.length / batchSize)} completed (${data.length} items)`);
        }
        
        console.log(`✅ Generated ${this.transactionItems.length} transaction items`);
    }

    async generateSubstitutions() {
        console.log(`🔄 Generating product substitutions...`);
        
        const substitutions = [];
        const substitutionCount = Math.floor(this.transactions.length * 0.05); // 5% of transactions have substitutions
        
        for (let i = 0; i < substitutionCount; i++) {
            const transaction = getRandomElement(this.transactions);
            const originalProduct = getRandomElement(this.products);
            const substituteProduct = getRandomElement(this.products.filter(p => p.category === originalProduct.category && p.id !== originalProduct.id));
            
            if (substituteProduct) {
                substitutions.push({
                    transaction_id: transaction.id,
                    original_product_id: originalProduct.id,
                    substitute_product_id: substituteProduct.id,
                    reason: getRandomElement(['Out of Stock', 'Customer Preference', 'Price', 'Promotion']),
                    customer_satisfaction_score: getRandomNumber(1, 5),
                    was_accepted: Math.random() > 0.3
                });
            }
        }

        const { data, error } = await supabase.from('substitutions').insert(substitutions).select();
        if (error) throw error;
        
        this.substitutions = data;
        console.log(`✅ Generated ${data.length} substitutions`);
    }

    async generateDeviceHealth() {
        console.log(`📊 Generating device health records...`);
        
        const healthRecords = [];
        const recordsPerDevice = 100; // About 100 health records per device
        
        for (const device of this.devices) {
            for (let i = 0; i < recordsPerDevice; i++) {
                const status = getRandomElement(['online', 'online', 'online', 'offline', 'maintenance', 'error']);
                
                healthRecords.push({
                    device_id: device.device_id,
                    store_id: device.store_id,
                    status: status,
                    cpu_usage: status === 'offline' ? null : getRandomDecimal(10, 95),
                    memory_usage: status === 'offline' ? null : getRandomDecimal(20, 85),
                    disk_usage: status === 'offline' ? null : getRandomDecimal(15, 90),
                    network_latency: status === 'offline' ? null : getRandomNumber(10, 200),
                    last_heartbeat: faker.date.recent({ days: 7 }),
                    error_count: status === 'error' ? getRandomNumber(1, 10) : 0,
                    uptime_hours: status === 'offline' ? 0 : getRandomDecimal(0, 168) // 1 week max
                });
            }
        }

        const batchSize = 2000;
        for (let i = 0; i < healthRecords.length; i += batchSize) {
            const batch = healthRecords.slice(i, i + batchSize);
            const { data, error } = await supabase.from('device_health').insert(batch).select();
            if (error) throw error;
            
            this.deviceHealthRecords.push(...data);
        }
        
        console.log(`✅ Generated ${this.deviceHealthRecords.length} device health records`);
    }

    async generateRequestBehaviors() {
        console.log(`🔍 Generating request behaviors...`);
        
        const behaviors = [];
        const behaviorCount = Math.floor(this.transactions.length * 0.3); // 30% of transactions have request behaviors
        
        for (let i = 0; i < behaviorCount; i++) {
            const store = getRandomElement(this.stores);
            const customer = Math.random() > 0.2 ? getRandomElement(this.customers) : null;
            
            behaviors.push({
                customer_id: customer?.id || null,
                store_id: store.id,
                request_type: getRandomElement(['product_search', 'price_inquiry', 'location_query', 'recommendation_request']),
                request_category: getRandomElement(['Product Information', 'Navigation', 'Pricing', 'Recommendations']),
                request_details: { query: faker.lorem.sentence() },
                response_time_ms: getRandomNumber(100, 5000),
                was_successful: Math.random() > 0.1,
                timestamp: faker.date.recent({ days: 30 })
            });
        }

        const batchSize = 2000;
        for (let i = 0; i < behaviors.length; i += batchSize) {
            const batch = behaviors.slice(i, i + batchSize);
            const { data, error } = await supabase.from('request_behaviors').insert(batch).select();
            if (error) throw error;
            
            this.requestBehaviors.push(...data);
        }
        
        console.log(`✅ Generated ${this.requestBehaviors.length} request behaviors`);
    }

    async generateCustomerRequests() {
        console.log(`📝 Generating customer requests...`);
        
        const requests = [];
        const requestCount = Math.floor(this.customers.length * 0.1); // 10% of customers have requests
        
        for (let i = 0; i < requestCount; i++) {
            const customer = getRandomElement(this.customers);
            const store = getRandomElement(this.stores);
            const product = Math.random() > 0.3 ? getRandomElement(this.products) : null;
            
            requests.push({
                customer_id: customer.id,
                store_id: store.id,
                request_type: getRandomElement(['Product Request', 'Stock Inquiry', 'Complaint', 'Suggestion']),
                product_category: product?.category || getRandomElement(FMCG_CATEGORIES),
                specific_product_id: product?.id || null,
                request_description: faker.lorem.paragraph(),
                urgency_level: getRandomNumber(1, 5),
                status: getRandomElement(['pending', 'processing', 'fulfilled', 'cancelled']),
                fulfilled_at: Math.random() > 0.5 ? faker.date.recent({ days: 10 }) : null
            });
        }

        const { data, error } = await supabase.from('customer_requests').insert(requests).select();
        if (error) throw error;
        
        this.customerRequests = data;
        console.log(`✅ Generated ${data.length} customer requests`);
    }

    async generateEdgeLogs() {
        console.log(`📋 Generating edge logs...`);
        
        const logs = [];
        const logsPerDevice = 50; // 50 logs per device
        
        for (const device of this.devices) {
            for (let i = 0; i < logsPerDevice; i++) {
                const logLevel = getRandomElement(['DEBUG', 'INFO', 'INFO', 'WARN', 'ERROR', 'FATAL']);
                
                logs.push({
                    device_id: device.device_id,
                    store_id: device.store_id,
                    log_level: logLevel,
                    message: faker.lorem.sentence(),
                    component: getRandomElement(['Scanner', 'Display', 'Network', 'Storage', 'CPU']),
                    error_code: logLevel === 'ERROR' || logLevel === 'FATAL' ? `ERR-${getRandomNumber(1000, 9999)}` : null,
                    metadata: { 
                        session_id: faker.string.uuid(),
                        user_agent: faker.internet.userAgent()
                    },
                    timestamp: faker.date.recent({ days: 30 })
                });
            }
        }

        const batchSize = 2000;
        for (let i = 0; i < logs.length; i += batchSize) {
            const batch = logs.slice(i, i + batchSize);
            const { data, error } = await supabase.from('edge_logs').insert(batch).select();
            if (error) throw error;
            
            this.edgeLogs.push(...data);
        }
        
        console.log(`✅ Generated ${this.edgeLogs.length} edge logs`);
    }

    async refreshMaterializedViews() {
        console.log(`🔄 Refreshing materialized views...`);
        
        const { error } = await supabase.rpc('refresh_analytical_views');
        if (error) {
            console.warn(`⚠️  Could not refresh materialized views: ${error.message}`);
        } else {
            console.log(`✅ Materialized views refreshed`);
        }
    }

    async generateAll() {
        console.log(`🚀 Starting Scout Analytics seed data generation...`);
        console.log(`Target: 18,000+ total records across all tables\n`);
        
        try {
            await this.generateBrands(50);
            await this.generateProducts(500);
            await this.generateCustomers(2000);
            await this.generateStores(100);
            await this.generateDevices();
            await this.generateTransactions(18000);
            await this.generateTransactionItems();
            await this.generateSubstitutions();
            await this.generateDeviceHealth();
            await this.generateRequestBehaviors();
            await this.generateCustomerRequests();
            await this.generateEdgeLogs();
            await this.refreshMaterializedViews();
            
            console.log(`\n🎉 Seed data generation completed successfully!`);
            console.log(`📊 Summary:`);
            console.log(`   • ${this.brands.length} brands`);
            console.log(`   • ${this.products.length} products`);
            console.log(`   • ${this.customers.length} customers`);
            console.log(`   • ${this.stores.length} stores`);
            console.log(`   • ${this.devices.length} devices`);
            console.log(`   • ${this.transactions.length} transactions`);
            console.log(`   • ${this.transactionItems.length} transaction items`);
            console.log(`   • ${this.substitutions.length} substitutions`);
            console.log(`   • ${this.deviceHealthRecords.length} device health records`);
            console.log(`   • ${this.requestBehaviors.length} request behaviors`);
            console.log(`   • ${this.customerRequests.length} customer requests`);
            console.log(`   • ${this.edgeLogs.length} edge logs`);
            
            const totalRecords = this.brands.length + this.products.length + this.customers.length + 
                               this.stores.length + this.devices.length + this.transactions.length + 
                               this.transactionItems.length + this.substitutions.length + 
                               this.deviceHealthRecords.length + this.requestBehaviors.length + 
                               this.customerRequests.length + this.edgeLogs.length;
            
            console.log(`\n📈 Total records generated: ${totalRecords.toLocaleString()}`);
            
        } catch (error) {
            console.error(`❌ Error during seed data generation:`, error);
            throw error;
        }
    }
}

// Main execution
async function main() {
    const generator = new SeedDataGenerator();
    await generator.generateAll();
}

if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch(console.error);
}

export default SeedDataGenerator;