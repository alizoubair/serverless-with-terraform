import { S3 } from '@aws-sdk/client-s3';
import { finished } from 'stream/promises';

console.log('Loading function');
const s3 = new S3();
// Importing 'fs/promises' for promise-based operations
import fs from 'fs/promises';
const SOURCE_BUCKET = process.env.SRC_BUCKET;
const DEST_BUCKET = process.env.DEST_BUCKET;

export const handler = async (event) => {
    console.log(event);
    let employeeId;

    if (event.Records) {
        const sqsMessage = JSON.parse(event.Records[0].body);
        employeeId = sqsMessage.employeeId;
    } else if (event.body) {
        const apiGatewayBody = JSON.parse(event.body);
        employeeId = apiGatewayBody.employeeId;
    } else {
        console.error("Unsupported event source");
        return;
    }

    console.log("EmployeeId", employeeId);
    console.log("Source File: ", `${employeeId}.jpeg`);

    try {
        const result = await s3.getObject({
            Bucket: SOURCE_BUCKET,
            Key: `${employeeId}.jpeg`
        });

        // Convert the stream to a buffer
        const chunks = [];
        result.Body.on('data', (chunk) => chunks.push(chunk));

        await finished(result.Body);

        const buffer = Buffer.concat(chunks);

        if (!Buffer.isBuffer(buffer)) {
            console.error("The fetched object is not a buffer");
        }

        const imageBase64 = buffer.toString('base64');

        // Create the HTML content with the embedded image
        const html = `
            <html>
                <head>
                    <title>Greeting Card</title>
                    <style>
                        body {
                        text-align: center;
                        font-family: 'Comic Sans MS', 'Arial', sans-serif;
                        background-color: #f0e4d7;
                        margin: 0;
                        padding: 0;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        min-height: 100vh;
                    }
                        h1 {
                        font-size: 2em;
                        color: #ff6347; /* Tomato */
                        text-shadow: 2px 2px 4px #000000;
                        margin: 0.5em 0;
                    }
                        img {
                        max-width: 80%;
                        border: 5px solid #ddd;
                        border-radius: 10px;
                        box-shadow: 0 0 10px #0008;
                        transition: transform 0.5s ease;
                    }
                        img:hover {
                        transform: scale(1.05);
                    }
                        .container {
                        background-color: white;
                        padding: 20px;
                        border-radius: 15px;
                        box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
                    }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>Happy Terraform Development!</h1>
                        <img src="data:image/jpeg;base64,${imageBase64}" alt="Employee Image">
                    </div>
                </body>
            </html>
        `;

        // Write the HTML to a file in /tmp
        const filePath = `/tmp/greeting-${employeeId}.html`;
        await fs.writeFile(filePath, html);

        // Upload the HTML file to the destination bucket
        const fileContent = await fs.readFile(filePath);
        await s3.putObject({
            Bucket: DEST_BUCKET,
            Key: `greeting-${employeeId}.html`,
            Body: fileContent,
            ContentType: 'text/html'
        });

        // Delete the HTML file from /tmp
        await fs.unlink(filePath);

        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'HTML greeting card created and uploaded successfully' })
        };
    } catch (error) {
        console.error("Error processing event: ", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Error processing your request'})
        };
    }
}