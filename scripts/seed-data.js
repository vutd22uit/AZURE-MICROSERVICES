/**
 * ================================================================
 * Big Data Generator for E-Commerce System
 * ================================================================
 * This script generates production-scale data:
 * - 100,000 users
 * - 500,000 orders
 * - 1,000 products
 * - Total size: >4GB
 *
 * Usage:
 *   node seed-data.js
 *
 * Environment Variables:
 *   COSMOS_DB_ENDPOINT - Cosmos DB endpoint
 *   COSMOS_DB_KEY - Cosmos DB primary key
 *   COSMOS_DB_DATABASE - Database name (default: ordersdb)
 *   BATCH_SIZE - Batch insert size (default: 100)
 * ================================================================
 */

const { CosmosClient } = require('@azure/cosmos');
const { faker } = require('@faker-js/faker');

// ================================================================
// Configuration
// ================================================================

const config = {
    endpoint: process.env.COSMOS_DB_ENDPOINT,
    key: process.env.COSMOS_DB_KEY,
    database: process.env.COSMOS_DB_DATABASE || 'ordersdb',
    batchSize: parseInt(process.env.BATCH_SIZE) || 100,

    // Data generation targets
    totalUsers: 100000,
    totalProducts: 1000,
    totalOrders: 500000,
};

// Validate environment
if (!config.endpoint || !config.key) {
    console.error('❌ Error: COSMOS_DB_ENDPOINT and COSMOS_DB_KEY must be set');
    process.exit(1);
}

// ================================================================
// Cosmos DB Client
// ================================================================

const client = new CosmosClient({
    endpoint: config.endpoint,
    key: config.key
});

const database = client.database(config.database);

// ================================================================
// Data Generation Functions
// ================================================================

/**
 * Generate a random product
 */
function generateProduct(id) {
    const categories = [
        'Electronics', 'Clothing', 'Books', 'Home & Kitchen',
        'Sports', 'Toys', 'Beauty', 'Automotive', 'Food & Beverages'
    ];

    const category = faker.helpers.arrayElement(categories);
    const product = {
        id: `prod-${id.toString().padStart(6, '0')}`,
        name: faker.commerce.productName(),
        category: category,
        price: parseFloat(faker.commerce.price({ min: 10, max: 1000, dec: 2 })),
        description: faker.commerce.productDescription(),
        imageUrl: faker.image.url({ width: 640, height: 480 }),
        stock: faker.number.int({ min: 0, max: 1000 }),
        rating: faker.number.float({ min: 1, max: 5, precision: 0.1 }),
        reviews: faker.number.int({ min: 0, max: 500 }),
        brand: faker.company.name(),
        sku: faker.string.alphanumeric(10).toUpperCase(),
        weight: faker.number.float({ min: 0.1, max: 50, precision: 0.01 }),
        dimensions: {
            length: faker.number.float({ min: 5, max: 100, precision: 0.1 }),
            width: faker.number.float({ min: 5, max: 100, precision: 0.1 }),
            height: faker.number.float({ min: 5, max: 100, precision: 0.1 })
        },
        tags: Array.from({ length: faker.number.int({ min: 2, max: 5 }) }, () => faker.word.noun()),
        createdAt: faker.date.past({ years: 2 }).toISOString(),
        updatedAt: new Date().toISOString()
    };

    return product;
}

/**
 * Generate a random order
 */
function generateOrder(id, userId, products) {
    const numItems = faker.number.int({ min: 1, max: 10 });
    const selectedProducts = faker.helpers.arrayElements(products, numItems);

    const items = selectedProducts.map(product => ({
        productId: product.id,
        productName: product.name,
        quantity: faker.number.int({ min: 1, max: 5 }),
        price: product.price,
        subtotal: product.price * faker.number.int({ min: 1, max: 5 })
    }));

    const totalAmount = items.reduce((sum, item) => sum + item.subtotal, 0);

    const statuses = ['Pending', 'Paid', 'Shipped', 'Delivered', 'Cancelled'];
    const status = faker.helpers.arrayElement(statuses);

    const paymentMethods = ['Credit Card', 'Debit Card', 'PayPal', 'Bank Transfer'];

    const createdAt = faker.date.past({ years: 1 });

    const order = {
        id: `ord-${id.toString().padStart(8, '0')}`,
        userId: userId,
        items: items,
        totalAmount: parseFloat(totalAmount.toFixed(2)),
        status: status,
        paymentMethod: faker.helpers.arrayElement(paymentMethods),
        shippingAddress: {
            street: faker.location.streetAddress(),
            city: faker.location.city(),
            state: faker.location.state(),
            zipCode: faker.location.zipCode(),
            country: faker.location.country()
        },
        transactionId: status === 'Paid' || status === 'Shipped' || status === 'Delivered'
            ? `txn-${faker.string.alphanumeric(16)}`
            : null,
        createdAt: createdAt.toISOString(),
        updatedAt: new Date(createdAt.getTime() + faker.number.int({ min: 0, max: 86400000 * 7 })).toISOString(),
        paidAt: status !== 'Pending' && status !== 'Cancelled'
            ? new Date(createdAt.getTime() + faker.number.int({ min: 3600000, max: 86400000 })).toISOString()
            : null
    };

    return order;
}

/**
 * Batch insert documents to Cosmos DB
 */
async function batchInsert(container, documents, entityName) {
    const batches = [];
    for (let i = 0; i < documents.length; i += config.batchSize) {
        batches.push(documents.slice(i, i + config.batchSize));
    }

    let inserted = 0;
    for (let i = 0; i < batches.length; i++) {
        const batch = batches[i];

        try {
            await Promise.all(
                batch.map(doc => container.items.create(doc))
            );

            inserted += batch.length;
            const progress = ((inserted / documents.length) * 100).toFixed(1);
            process.stdout.write(`\r   Progress: ${inserted.toLocaleString()}/${documents.length.toLocaleString()} (${progress}%) ${entityName}`);
        } catch (error) {
            console.error(`\n❌ Error inserting batch: ${error.message}`);
        }
    }

    console.log(`\n✅ Inserted ${inserted.toLocaleString()} ${entityName}`);
    return inserted;
}

// ================================================================
// Main Execution
// ================================================================

async function main() {
    console.log('═══════════════════════════════════════════════════════');
    console.log('  BIG DATA GENERATOR - E-Commerce Cloud System');
    console.log('═══════════════════════════════════════════════════════\n');

    console.log('📋 Configuration:');
    console.log(`   Database: ${config.database}`);
    console.log(`   Target Users: ${config.totalUsers.toLocaleString()}`);
    console.log(`   Target Products: ${config.totalProducts.toLocaleString()}`);
    console.log(`   Target Orders: ${config.totalOrders.toLocaleString()}`);
    console.log(`   Batch Size: ${config.batchSize}\n`);

    const startTime = Date.now();

    try {
        // ================================================================
        // 1. Generate Products
        // ================================================================
        console.log('📦 Step 1/3: Generating Products...');
        const products = [];
        for (let i = 1; i <= config.totalProducts; i++) {
            products.push(generateProduct(i));
        }

        const productsContainer = database.container('products');
        await batchInsert(productsContainer, products, 'products');

        // ================================================================
        // 2. Generate Orders (split into chunks for memory efficiency)
        // ================================================================
        console.log('\n📋 Step 2/3: Generating Orders...');
        const ordersContainer = database.container('orders');

        const chunkSize = 50000; // Generate in chunks to avoid memory issues
        let totalOrdersInserted = 0;

        for (let chunk = 0; chunk < Math.ceil(config.totalOrders / chunkSize); chunk++) {
            const start = chunk * chunkSize;
            const end = Math.min(start + chunkSize, config.totalOrders);
            const chunkOrders = [];

            console.log(`\n   Chunk ${chunk + 1}/${Math.ceil(config.totalOrders / chunkSize)}: Generating orders ${start + 1} to ${end}...`);

            for (let i = start; i < end; i++) {
                // Distribute orders across users
                const userId = `user-${faker.number.int({ min: 1, max: config.totalUsers }).toString().padStart(6, '0')}`;
                chunkOrders.push(generateOrder(i + 1, userId, products));
            }

            const inserted = await batchInsert(ordersContainer, chunkOrders, 'orders');
            totalOrdersInserted += inserted;
        }

        // ================================================================
        // 3. Statistics
        // ================================================================
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000 / 60).toFixed(2);

        console.log('\n═══════════════════════════════════════════════════════');
        console.log('  ✅ DATA GENERATION COMPLETE!');
        console.log('═══════════════════════════════════════════════════════\n');

        console.log('📊 Statistics:');
        console.log(`   Products Created: ${products.length.toLocaleString()}`);
        console.log(`   Orders Created: ${totalOrdersInserted.toLocaleString()}`);
        console.log(`   Estimated Data Size: ~${((totalOrdersInserted * 2) / 1024).toFixed(2)} GB`);
        console.log(`   Time Elapsed: ${duration} minutes`);
        console.log(`   Average Rate: ${(totalOrdersInserted / (duration * 60)).toFixed(0)} orders/second\n`);

        console.log('🎯 Next Steps:');
        console.log('   1. Run ETL pipeline: az datafactory pipeline create-run...');
        console.log('   2. Check Synapse Analytics for data');
        console.log('   3. Refresh Power BI reports\n');

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Run if executed directly
if (require.main === module) {
    main();
}

module.exports = { generateProduct, generateOrder };
