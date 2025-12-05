/**
 * ================================================================
 * Azure Function: Payment Processor
 * ================================================================
 * This serverless function processes payments for orders
 *
 * Trigger: HTTP POST
 * Input: { orderId, userId, amount, paymentMethod }
 * Output: { success, transactionId, message }
 *
 * Features:
 * - Validates payment information
 * - Simulates payment processing (90% success rate)
 * - Updates order status in Cosmos DB
 * - Triggers email notification function
 * - Logs to Application Insights
 * ================================================================
 */

const { CosmosClient } = require("@azure/cosmos");
const axios = require("axios");

module.exports = async function (context, req) {
    context.log('Payment Processor function triggered');

    try {
        // ================================================================
        // 1. Validate Input
        // ================================================================
        const { orderId, userId, amount, paymentMethod } = req.body;

        if (!orderId || !userId || !amount || !paymentMethod) {
            context.res = {
                status: 400,
                body: {
                    success: false,
                    message: 'Missing required fields: orderId, userId, amount, paymentMethod'
                }
            };
            return;
        }

        if (amount <= 0) {
            context.res = {
                status: 400,
                body: {
                    success: false,
                    message: 'Invalid amount. Must be greater than 0'
                }
            };
            return;
        }

        const validPaymentMethods = ['Credit Card', 'Debit Card', 'PayPal', 'Bank Transfer'];
        if (!validPaymentMethods.includes(paymentMethod)) {
            context.res = {
                status: 400,
                body: {
                    success: false,
                    message: `Invalid payment method. Must be one of: ${validPaymentMethods.join(', ')}`
                }
            };
            return;
        }

        // ================================================================
        // 2. Simulate Payment Processing
        // ================================================================
        context.log(`Processing payment for order ${orderId}, amount: $${amount}, method: ${paymentMethod}`);

        // Simulate payment gateway delay
        await sleep(1000 + Math.random() * 2000); // 1-3 seconds

        // Simulate 90% success rate
        const isSuccess = Math.random() < 0.9;

        const transactionId = `txn-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const timestamp = new Date().toISOString();

        if (!isSuccess) {
            // Payment failed
            context.log.warn(`Payment failed for order ${orderId}`);

            // Update order status to 'Payment Failed'
            await updateOrderStatus(context, orderId, 'Payment Failed');

            context.res = {
                status: 200,
                body: {
                    success: false,
                    orderId: orderId,
                    transactionId: transactionId,
                    message: 'Payment processing failed. Please try again or use a different payment method.',
                    timestamp: timestamp,
                    errorCode: 'PAYMENT_DECLINED'
                }
            };
            return;
        }

        // ================================================================
        // 3. Payment Successful - Update Order
        // ================================================================
        context.log(`Payment successful for order ${orderId}, transaction: ${transactionId}`);

        await updateOrderStatus(context, orderId, 'Paid', transactionId);

        // ================================================================
        // 4. Trigger Email Notification
        // ================================================================
        try {
            const emailFunctionUrl = process.env.EMAIL_FUNCTION_URL;
            if (emailFunctionUrl) {
                await axios.post(emailFunctionUrl, {
                    userId: userId,
                    orderId: orderId,
                    transactionId: transactionId,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    timestamp: timestamp
                }, {
                    timeout: 5000
                });
                context.log(`Email notification triggered for order ${orderId}`);
            }
        } catch (emailError) {
            context.log.error(`Failed to trigger email notification: ${emailError.message}`);
            // Don't fail the payment if email fails
        }

        // ================================================================
        // 5. Return Success Response
        // ================================================================
        context.res = {
            status: 200,
            body: {
                success: true,
                orderId: orderId,
                transactionId: transactionId,
                amount: amount,
                paymentMethod: paymentMethod,
                message: 'Payment processed successfully',
                timestamp: timestamp,
                receiptUrl: `https://receipts.example.com/${transactionId}`
            }
        };

    } catch (error) {
        context.log.error(`Payment processing error: ${error.message}`);
        context.res = {
            status: 500,
            body: {
                success: false,
                message: 'Internal server error during payment processing',
                error: error.message
            }
        };
    }
};

// ================================================================
// Helper Functions
// ================================================================

/**
 * Update order status in Cosmos DB
 */
async function updateOrderStatus(context, orderId, status, transactionId = null) {
    try {
        const endpoint = process.env.COSMOS_DB_ENDPOINT;
        const key = process.env.COSMOS_DB_KEY;
        const databaseId = process.env.COSMOS_DB_DATABASE || 'ordersdb';

        if (!endpoint || !key) {
            context.log.error('Cosmos DB credentials not configured');
            return;
        }

        const client = new CosmosClient({ endpoint, key });
        const database = client.database(databaseId);
        const container = database.container('orders');

        // Query to find the order
        const querySpec = {
            query: "SELECT * FROM c WHERE c.id = @orderId",
            parameters: [
                {
                    name: "@orderId",
                    value: orderId
                }
            ]
        };

        const { resources: orders } = await container.items
            .query(querySpec)
            .fetchAll();

        if (orders.length === 0) {
            context.log.warn(`Order ${orderId} not found in Cosmos DB`);
            return;
        }

        const order = orders[0];
        order.status = status;
        order.updatedAt = new Date().toISOString();

        if (transactionId) {
            order.transactionId = transactionId;
            order.paidAt = new Date().toISOString();
        }

        await container.item(order.id, order.userId).replace(order);
        context.log(`Order ${orderId} updated to status: ${status}`);

    } catch (error) {
        context.log.error(`Failed to update order status: ${error.message}`);
        throw error;
    }
}

/**
 * Sleep utility function
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
