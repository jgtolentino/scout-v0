#!/usr/bin/env node

import { writeFileSync, mkdirSync } from 'fs';
import { v4 as uuidv4 } from 'uuid';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';

// Command line arguments
const argv = yargs(hideBin(process.argv))
  .option('count', { 
    type: 'number', 
    default: 5000, 
    description: 'Number of transactions to generate' 
  })
  .option('start', { 
    type: 'string', 
    default: '2024-01-01', 
    description: 'Start date (YYYY-MM-DD)' 
  })
  .option('end', { 
    type: 'string', 
    default: '2024-12-20', 
    description: 'End date (YYYY-MM-DD)' 
  })
  .option('output', { 
    type: 'string', 
    default: 'data/mockTransactions.json', 
    description: 'Output file path' 
  })
  .argv;

// TBWA Client & Competitor Brands & SKUs
const clientBrands = [
  {
    name: "Coca-Cola",
    category: "Beverages",
    skus: ["COKE-350ML", "COKE-500ML", "COKE-1L", "COKE-ZERO-350ML", "SPRITE-350ML", "FANTA-350ML"]
  },
  {
    name: "McDonald's",
    category: "Food & Beverage",
    skus: ["MCD-BURGER", "MCD-FRIES", "MCD-NUGGETS", "MCD-SUNDAE", "MCD-COFFEE"]
  },
  {
    name: "Nissan",
    category: "Automotive",
    skus: ["NISSAN-NAVARA", "NISSAN-ALMERA", "NISSAN-TERRA", "NISSAN-XTRAIL"]
  },
  {
    name: "Adidas",
    category: "Sportswear",
    skus: ["ADIDAS-ULTRABOOST", "ADIDAS-STAN-SMITH", "ADIDAS-ORIGINALS-TEE", "ADIDAS-SHORTS"]
  },
  {
    name: "Globe Telecom",
    category: "Telecommunications",
    skus: ["GLOBE-PREPAID-100", "GLOBE-PREPAID-300", "GLOBE-POSTPAID-1599", "GLOBE-WIFI"]
  }
];

const competitorBrands = [
  {
    name: "Pepsi",
    category: "Beverages", 
    skus: ["PEPSI-350ML", "PEPSI-500ML", "PEPSI-1L", "PEPSI-ZERO-350ML", "7UP-350ML", "MIRINDA-350ML"]
  },
  {
    name: "Jollibee",
    category: "Food & Beverage",
    skus: ["JB-CHICKENJOY", "JB-BURGER", "JB-SPAGHETTI", "JB-PEACH-PIE", "JB-COFFEE"]
  },
  {
    name: "Toyota",
    category: "Automotive", 
    skus: ["TOYOTA-HILUX", "TOYOTA-VIOS", "TOYOTA-FORTUNER", "TOYOTA-RAV4"]
  },
  {
    name: "Nike",
    category: "Sportswear",
    skus: ["NIKE-AIR-MAX", "NIKE-REACT", "NIKE-DRI-FIT-TEE", "NIKE-SHORTS"]
  },
  {
    name: "Smart Communications",
    category: "Telecommunications",
    skus: ["SMART-PREPAID-100", "SMART-PREPAID-300", "SMART-POSTPAID-1499", "SMART-BRO"]
  },
  {
    name: "San Miguel",
    category: "Beverages",
    skus: ["SMB-PALE-PILSEN", "SMB-LIGHT", "SMB-PREMIUM", "SMB-FLAVORED"]
  },
  {
    name: "Nestle",
    category: "Food & Beverage",
    skus: ["NESCAFE-3IN1", "MAGGI-NOODLES", "MILO-POWDER", "BEAR-BRAND-MILK"]
  },
  {
    name: "Unilever",
    category: "Personal Care",
    skus: ["DOVE-SOAP", "CLEAR-SHAMPOO", "CLOSEUP-TOOTHPASTE", "VASELINE-LOTION"]
  }
];

// Philippine Regions with realistic weights and cities
const regions = [
  {
    code: "NCR",
    name: "National Capital Region",
    weight: 0.35,
    cities: ["Manila", "Quezon City", "Makati", "Pasig", "Taguig", "Mandaluyong", "Pasay", "Caloocan"]
  },
  {
    code: "CAR", 
    name: "Cordillera Administrative Region",
    weight: 0.03,
    cities: ["Baguio", "Tabuk", "Bangued", "Lagawe", "Bontoc", "Mayoyao"]
  },
  {
    code: "R01",
    name: "Ilocos Region",
    weight: 0.08,
    cities: ["Laoag", "Vigan", "San Fernando", "Dagupan", "Alaminos", "Urdaneta"]
  },
  {
    code: "R02",
    name: "Cagayan Valley", 
    weight: 0.05,
    cities: ["Tuguegarao", "Ilagan", "Santiago", "Cauayan", "Bayombong"]
  },
  {
    code: "R03",
    name: "Central Luzon",
    weight: 0.12,
    cities: ["San Fernando", "Angeles", "Olongapo", "Malolos", "Cabanatuan", "Tarlac", "Balanga"]
  },
  {
    code: "R04A",
    name: "Calabarzon",
    weight: 0.15,
    cities: ["Calamba", "Santa Rosa", "Antipolo", "Dasmarinas", "Bacoor", "Lucena", "Batangas"]
  },
  {
    code: "R06",
    name: "Western Visayas",
    weight: 0.08,
    cities: ["Iloilo", "Bacolod", "Roxas", "Kalibo", "San Jose de Buenavista"]
  },
  {
    code: "R07",
    name: "Central Visayas",
    weight: 0.09,
    cities: ["Cebu", "Lapu-Lapu", "Mandaue", "Tagbilaran", "Dumaguete", "Siquijor"]
  },
  {
    code: "R11",
    name: "Davao Region",
    weight: 0.07,
    cities: ["Davao", "Tagum", "Panabo", "Digos", "Mati"]
  }
];

// Consumer profile options
const ageBrackets = ["18-24", "25-34", "35-44", "45-54", "55+"];
const incomeClasses = ["A", "B", "C1", "C2", "D", "E"];
const payments = ["Cash", "GCash", "Maya", "Credit Card", "Debit Card", "Bank Transfer"];
const genders = ["Male", "Female"];

// Store types and sizes
const storeTypes = ["Sari-sari Store", "Convenience Store", "Grocery", "Supermarket", "Hypermarket"];
const storeSizes = ["Small", "Medium", "Large"];

// Hourly weights (24 hours) - peak at lunch and dinner
const hourlyWeights = [
  0.5, 0.3, 0.2, 0.2, 0.3, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, // 0-11 AM
  5.0, 4.5, 4.0, 3.5, 3.0, 4.0, 5.5, 6.0, 4.5, 3.0, 2.0, 1.0  // 12-11 PM
];

// Day of week weights (0=Sunday, 6=Saturday)
const dayOfWeekWeights = [0.8, 1.0, 1.0, 1.0, 1.0, 1.2, 1.3]; // Weekend slightly higher

// Helper functions
function weightedRandomRegion() {
  let r = Math.random();
  let acc = 0;
  for (const region of regions) {
    acc += region.weight;
    if (r <= acc) return region;
  }
  return regions[regions.length - 1];
}

function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function weightedRandomHour() {
  let r = Math.random() * hourlyWeights.reduce((a, b) => a + b, 0);
  let acc = 0;
  for (let i = 0; i < hourlyWeights.length; i++) {
    acc += hourlyWeights[i];
    if (r <= acc) return i;
  }
  return 12; // default to noon
}

function generateRealisticDateTime(startDate, endDate) {
  const start = new Date(startDate).getTime();
  const end = new Date(endDate).getTime();
  const randomTime = start + Math.random() * (end - start);
  const date = new Date(randomTime);
  
  // Apply day of week weighting
  const dayOfWeek = date.getDay();
  if (Math.random() > dayOfWeekWeights[dayOfWeek] / Math.max(...dayOfWeekWeights)) {
    return generateRealisticDateTime(startDate, endDate); // retry
  }
  
  // Set realistic hour
  const hour = weightedRandomHour();
  const minute = Math.floor(Math.random() * 60);
  const second = Math.floor(Math.random() * 60);
  
  date.setHours(hour, minute, second, 0);
  return date.toISOString();
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFloat(min, max, decimals = 2) {
  return parseFloat((Math.random() * (max - min) + min).toFixed(decimals));
}

function generateRealisticPrice(category, sku) {
  const basePrices = {
    "Beverages": { min: 15, max: 200 },
    "Food & Beverage": { min: 25, max: 500 },
    "Automotive": { min: 800000, max: 2500000 },
    "Sportswear": { min: 1500, max: 15000 },
    "Telecommunications": { min: 100, max: 2500 },
    "Personal Care": { min: 50, max: 800 }
  };
  
  const range = basePrices[category] || { min: 20, max: 300 };
  
  // Size-based pricing
  if (sku.includes("1L") || sku.includes("LARGE")) {
    range.min *= 1.5;
    range.max *= 1.5;
  } else if (sku.includes("500ML") || sku.includes("MEDIUM")) {
    range.min *= 1.2;
    range.max *= 1.2;
  }
  
  return randomFloat(range.min, range.max);
}

// Main generation function
function generateMockTransactions(count, startDate, endDate) {
  console.log(`🚀 Generating ${count} mock transactions...`);
  console.log(`📅 Date range: ${startDate} to ${endDate}`);
  
  const transactions = [];
  const customers = new Map(); // Cache customers for repeat purchases
  const stores = new Map(); // Cache stores by region
  
  for (let i = 0; i < count; i++) {
    const region = weightedRandomRegion();
    const city = randomElement(region.cities);
    const barangay = `Barangay ${randomInt(1, 100)}`;
    const storeType = randomElement(storeTypes);
    
    // Get or create store for this region
    const storeKey = `${region.code}-${city}-${storeType}`;
    let store = stores.get(storeKey);
    if (!store) {
      store = {
        id: uuidv4(),
        code: `STORE-${region.code}-${String(stores.size + 1).padStart(3, '0')}`,
        name: `${city} ${storeType}`,
        type: storeType,
        size: randomElement(storeSizes),
        region: region.code,
        city,
        barangay
      };
      stores.set(storeKey, store);
    }
    
    // Customer profile with repeat customer logic
    let customer = null;
    if (Math.random() < 0.3 && customers.size > 0) {
      // 30% chance of repeat customer
      customer = randomElement(Array.from(customers.values()));
    } else {
      // New customer
      customer = {
        id: uuidv4(),
        code: `CUST-${String(customers.size + 1).padStart(6, '0')}`,
        gender: randomElement(genders),
        age_bracket: randomElement(ageBrackets),
        income_class: randomElement(incomeClasses),
        region: region.code,
        city,
        barangay
      };
      customers.set(customer.id, customer);
    }
    
    // Generate basket items
    const basketSize = randomInt(1, 8);
    const basketItems = [];
    const usedSkus = new Set(); // Prevent duplicate SKUs in same transaction
    
    for (let j = 0; j < basketSize; j++) {
      // 60% client brands, 40% competitor brands
      const brandSet = Math.random() < 0.6 ? clientBrands : competitorBrands;
      const brand = randomElement(brandSet);
      let sku;
      let attempts = 0;
      
      // Find unused SKU
      do {
        sku = randomElement(brand.skus);
        attempts++;
      } while (usedSkus.has(sku) && attempts < 10);
      
      if (!usedSkus.has(sku)) {
        usedSkus.add(sku);
        
        const quantity = randomInt(1, 5);
        const unitPrice = generateRealisticPrice(brand.category, sku);
        
        basketItems.push({
          sku,
          product_name: `${brand.name} ${sku.replace(/-/g, ' ')}`,
          brand: brand.name,
          category: brand.category,
          quantity,
          unit_price: unitPrice,
          total_price: parseFloat((quantity * unitPrice).toFixed(2))
        });
      }
    }
    
    // Calculate totals
    const subtotal = basketItems.reduce((sum, item) => sum + item.total_price, 0);
    const discountRate = Math.random() < 0.2 ? randomFloat(0.05, 0.25) : 0; // 20% chance of discount
    const discountAmount = parseFloat((subtotal * discountRate).toFixed(2));
    const taxRate = 0.12; // 12% VAT in Philippines
    const taxableAmount = subtotal - discountAmount;
    const taxAmount = parseFloat((taxableAmount * taxRate).toFixed(2));
    const totalAmount = parseFloat((taxableAmount + taxAmount).toFixed(2));
    
    // Create transaction
    const transaction = {
      id: uuidv4(),
      transaction_code: `TXN-${String(i + 1).padStart(8, '0')}`,
      timestamp: generateRealisticDateTime(startDate, endDate),
      customer_id: customer.id,
      customer_profile: {
        gender: customer.gender,
        age_bracket: customer.age_bracket,
        income_class: customer.income_class,
        region: customer.region,
        city: customer.city
      },
      store_id: store.id,
      store_info: {
        code: store.code,
        name: store.name,
        type: store.type,
        size: store.size,
        region: store.region,
        city: store.city,
        barangay: store.barangay
      },
      items: basketItems,
      transaction_summary: {
        item_count: basketItems.length,
        total_quantity: basketItems.reduce((sum, item) => sum + item.quantity, 0),
        subtotal: parseFloat(subtotal.toFixed(2)),
        discount_amount: discountAmount,
        tax_amount: taxAmount,
        total_amount: totalAmount
      },
      payment_method: randomElement(payments),
      metadata: {
        day_of_week: new Date(generateRealisticDateTime(startDate, endDate)).getDay(),
        hour_of_day: new Date(generateRealisticDateTime(startDate, endDate)).getHours(),
        is_weekend: [0, 6].includes(new Date(generateRealisticDateTime(startDate, endDate)).getDay()),
        channel: "Retail",
        device_id: `POS-${store.code}-01`
      }
    };
    
    transactions.push(transaction);
    
    // Progress indicator
    if ((i + 1) % 1000 === 0) {
      console.log(`   📊 Generated ${i + 1}/${count} transactions...`);
    }
  }
  
  console.log(`✅ Generated ${transactions.length} transactions`);
  console.log(`👥 Unique customers: ${customers.size}`);
  console.log(`🏪 Unique stores: ${stores.size}`);
  
  return {
    transactions,
    customers: Array.from(customers.values()),
    stores: Array.from(stores.values()),
    summary: {
      total_transactions: transactions.length,
      unique_customers: customers.size,
      unique_stores: stores.size,
      date_range: { start: startDate, end: endDate },
      total_revenue: transactions.reduce((sum, t) => sum + t.transaction_summary.total_amount, 0)
    }
  };
}

// Main execution
async function main() {
  try {
    const { count, start, end, output } = argv;
    
    // Generate data
    const data = generateMockTransactions(count, start, end);
    
    // Ensure output directory exists
    const outputDir = output.substring(0, output.lastIndexOf('/'));
    if (outputDir) {
      mkdirSync(outputDir, { recursive: true });
    }
    
    // Write to file
    writeFileSync(output, JSON.stringify(data, null, 2), 'utf-8');
    
    console.log(`\n🎉 Mock data generation completed!`);
    console.log(`📁 Output written to: ${output}`);
    console.log(`📊 Summary:`);
    console.log(`   • Transactions: ${data.summary.total_transactions.toLocaleString()}`);
    console.log(`   • Customers: ${data.summary.unique_customers.toLocaleString()}`);
    console.log(`   • Stores: ${data.summary.unique_stores.toLocaleString()}`);
    console.log(`   • Total Revenue: ₱${data.summary.total_revenue.toLocaleString()}`);
    console.log(`   • Date Range: ${data.summary.date_range.start} to ${data.summary.date_range.end}`);
    
  } catch (error) {
    console.error(`❌ Error generating mock data:`, error);
    process.exit(1);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export default generateMockTransactions;