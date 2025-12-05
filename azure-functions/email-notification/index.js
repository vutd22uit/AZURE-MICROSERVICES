/**
 * ================================================================
 * Azure Function: Email Notification
 * ================================================================
 * This serverless function sends email notifications for orders
 *
 * Trigger: HTTP POST
 * Input: { userId, orderId, transactionId, amount, paymentMethod }
 * Output: { success, messageId, message }
 *
 * Features:
 * - Sends order confirmation emails
 * - Uses SendGrid for email delivery
 * - HTML email templates
 * - Logs to Application Insights
 * ================================================================
 */

const sgMail = require('@sendgrid/mail');

module.exports = async function (context, req) {
    context.log('Email Notification function triggered');

    try {
        // ================================================================
        // 1. Validate Input
        // ================================================================
        const { userId, orderId, transactionId, amount, paymentMethod, timestamp } = req.body;

        if (!userId || !orderId) {
            context.res = {
                status: 400,
                body: {
                    success: false,
                    message: 'Missing required fields: userId, orderId'
                }
            };
            return;
        }

        // ================================================================
        // 2. Configure SendGrid
        // ================================================================
        const sendgridApiKey = process.env.SENDGRID_API_KEY;
        const fromEmail = process.env.FROM_EMAIL || 'noreply@ecommerce-cloud.com';

        if (!sendgridApiKey || sendgridApiKey === 'your-sendgrid-api-key') {
            context.log.warn('SendGrid API key not configured. Simulating email send.');

            // Simulate email sending for demo purposes
            const messageId = `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

            context.log(`[SIMULATED] Email sent to user ${userId} for order ${orderId}`);

            context.res = {
                status: 200,
                body: {
                    success: true,
                    messageId: messageId,
                    message: 'Email notification simulated (SendGrid not configured)',
                    orderId: orderId,
                    timestamp: new Date().toISOString()
                }
            };
            return;
        }

        sgMail.setApiKey(sendgridApiKey);

        // ================================================================
        // 3. Get User Email (mock - in production, query from database)
        // ================================================================
        // In production, you would query the user service to get email
        const userEmail = `user-${userId}@example.com`;  // Mock email

        // ================================================================
        // 4. Create Email Content
        // ================================================================
        const emailSubject = `Order Confirmation - #${orderId}`;
        const emailHtml = generateEmailHtml(orderId, transactionId, amount, paymentMethod, timestamp);
        const emailText = generateEmailText(orderId, transactionId, amount, paymentMethod, timestamp);

        const msg = {
            to: userEmail,
            from: fromEmail,
            subject: emailSubject,
            text: emailText,
            html: emailHtml,
        };

        // ================================================================
        // 5. Send Email
        // ================================================================
        context.log(`Sending email to ${userEmail} for order ${orderId}`);

        const response = await sgMail.send(msg);
        const messageId = response[0].headers['x-message-id'];

        context.log(`Email sent successfully. Message ID: ${messageId}`);

        // ================================================================
        // 6. Return Success Response
        // ================================================================
        context.res = {
            status: 200,
            body: {
                success: true,
                messageId: messageId,
                message: 'Email notification sent successfully',
                recipient: userEmail,
                orderId: orderId,
                timestamp: new Date().toISOString()
            }
        };

    } catch (error) {
        context.log.error(`Email notification error: ${error.message}`);
        context.res = {
            status: 500,
            body: {
                success: false,
                message: 'Failed to send email notification',
                error: error.message
            }
        };
    }
};

// ================================================================
// Email Template Functions
// ================================================================

/**
 * Generate HTML email template
 */
function generateEmailHtml(orderId, transactionId, amount, paymentMethod, timestamp) {
    const formattedAmount = amount ? `$${amount.toFixed(2)}` : 'N/A';
    const formattedDate = timestamp ? new Date(timestamp).toLocaleString() : new Date().toLocaleString();

    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Order Confirmation</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #4CAF50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px 5px 0 0;
        }
        .content {
            background-color: #f9f9f9;
            padding: 30px;
            border: 1px solid #ddd;
            border-top: none;
            border-radius: 0 0 5px 5px;
        }
        .order-details {
            background-color: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
            border: 1px solid #e0e0e0;
        }
        .detail-row {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            padding: 10px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .detail-row:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: bold;
            color: #666;
        }
        .value {
            color: #333;
        }
        .success-icon {
            font-size: 48px;
            text-align: center;
            margin: 20px 0;
        }
        .button {
            display: inline-block;
            background-color: #4CAF50;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 5px;
            margin: 20px 0;
            text-align: center;
        }
        .footer {
            text-align: center;
            color: #999;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>✅ Payment Successful!</h1>
    </div>

    <div class="content">
        <div class="success-icon">🎉</div>

        <h2>Thank you for your order!</h2>
        <p>Your payment has been processed successfully. We'll start preparing your order right away.</p>

        <div class="order-details">
            <h3>Order Details</h3>

            <div class="detail-row">
                <span class="label">Order ID:</span>
                <span class="value">#${orderId}</span>
            </div>

            <div class="detail-row">
                <span class="label">Transaction ID:</span>
                <span class="value">${transactionId || 'N/A'}</span>
            </div>

            <div class="detail-row">
                <span class="label">Amount Paid:</span>
                <span class="value">${formattedAmount}</span>
            </div>

            <div class="detail-row">
                <span class="label">Payment Method:</span>
                <span class="value">${paymentMethod || 'N/A'}</span>
            </div>

            <div class="detail-row">
                <span class="label">Date & Time:</span>
                <span class="value">${formattedDate}</span>
            </div>
        </div>

        <div style="text-align: center;">
            <a href="https://ecommerce-cloud.com/orders/${orderId}" class="button">
                View Order Details
            </a>
        </div>

        <h3>What's Next?</h3>
        <ul>
            <li>📦 Your order is being prepared</li>
            <li>🚚 You'll receive a shipping notification soon</li>
            <li>📧 Check your email for updates</li>
        </ul>

        <p><strong>Need help?</strong> Contact our support team at support@ecommerce-cloud.com</p>
    </div>

    <div class="footer">
        <p>This is an automated email from E-Commerce Cloud System</p>
        <p>&copy; 2024 E-Commerce Cloud. All rights reserved.</p>
        <p>
            <a href="https://ecommerce-cloud.com/terms" style="color: #999;">Terms of Service</a> |
            <a href="https://ecommerce-cloud.com/privacy" style="color: #999;">Privacy Policy</a>
        </p>
    </div>
</body>
</html>
    `;
}

/**
 * Generate plain text email template
 */
function generateEmailText(orderId, transactionId, amount, paymentMethod, timestamp) {
    const formattedAmount = amount ? `$${amount.toFixed(2)}` : 'N/A';
    const formattedDate = timestamp ? new Date(timestamp).toLocaleString() : new Date().toLocaleString();

    return `
PAYMENT SUCCESSFUL!
===================

Thank you for your order!

Your payment has been processed successfully. We'll start preparing your order right away.

ORDER DETAILS:
--------------
Order ID: #${orderId}
Transaction ID: ${transactionId || 'N/A'}
Amount Paid: ${formattedAmount}
Payment Method: ${paymentMethod || 'N/A'}
Date & Time: ${formattedDate}

WHAT'S NEXT?
------------
- Your order is being prepared
- You'll receive a shipping notification soon
- Check your email for updates

View your order: https://ecommerce-cloud.com/orders/${orderId}

Need help? Contact our support team at support@ecommerce-cloud.com

---
This is an automated email from E-Commerce Cloud System
© 2024 E-Commerce Cloud. All rights reserved.
    `;
}
