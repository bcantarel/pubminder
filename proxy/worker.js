// PubMinder — Cloudflare Worker proxy for Groq summarization
//
// Deploy steps:
//   1. Install Wrangler: npm install -g wrangler
//   2. Log in:           wrangler login
//   3. Add your key:     wrangler secret put GROQ_API_KEY
//      (paste your gsk_... key when prompted — it is stored encrypted, never in code)
//   4. Deploy:           wrangler deploy
//      Wrangler will print your Worker URL, e.g.:
//      https://pubminder-proxy.YOUR_SUBDOMAIN.workers.dev
//   5. Copy that URL into fetchData.swift (search for WORKER_URL_HERE).
//
// The Worker accepts:
//   POST /summarize
//   Content-Type: application/json
//   Body: { "text": "<abstract text>" }
//
// It returns the raw Groq JSON response, which the iOS app parses exactly
// as it did when calling Groq directly — no changes to the response parser needed.

const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";
const SYSTEM_PROMPT =
  "You are a graduate research assistant. Summarize the following scientific " +
  "abstract for your peers in 2–3 sentences. Be specific about the key finding.";

export default {
  async fetch(request, env) {
    // Only accept POST /summarize
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/summarize") {
      return new Response("Not found", { status: 404 });
    }

    // Parse incoming body
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const text = body?.text;
    if (!text || typeof text !== "string" || text.trim() === "") {
      return new Response('Missing "text" field', { status: 400 });
    }

    // Call Groq — API key stays here, never reaches the client
    const groqPayload = {
      model: "llama-3.3-70b-versatile",
      temperature: 0,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user",   content: text },
      ],
    };

    const groqResponse = await fetch(GROQ_API_URL, {
      method: "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${env.GROQ_API_KEY}`,
      },
      body: JSON.stringify(groqPayload),
    });

    // Pass the Groq response back to the iOS app as-is
    // (same JSON shape the app already knows how to parse)
    return new Response(groqResponse.body, {
      status:  groqResponse.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};
