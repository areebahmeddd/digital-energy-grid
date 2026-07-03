const fs = require("fs");

// The stock sandbox /api/webhook/status handler emits an on_status callback.
// In Wave 2, degledgerrecorder owns that DISCOM cascade, so the sandbox should
// only log and ACK status while keeping normal webhook routing visible.
const ackOnlyStatusHandler = `const onStatus = (req, res) => {
    const { context, message } = req.body;
    console.log(JSON.stringify({ message, context }, null, 2));
    return res.status(200).json(buildAck(context));
};
exports.onStatus = onStatus;`;

const webhookControllerPath = "/app/dist/webhook/controller.js";
let webhookController = fs.readFileSync(webhookControllerPath, "utf8");

if (!webhookController.includes("sandbox ACK-only status customization")) {
  webhookController = webhookController.replace(
    /const onStatus = \(req, res\) => \{[\s\S]*?\};\nexports\.onStatus = onStatus;/,
    `// sandbox ACK-only status customization\n${ackOnlyStatusHandler}`
  );
  fs.writeFileSync(webhookControllerPath, webhookController);
  console.log("sandbox startup: made /api/webhook/status ACK-only");
} else {
  console.log("sandbox startup: /api/webhook/status is already ACK-only");
}
