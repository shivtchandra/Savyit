import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { verifyFirebaseIdToken } from "@/lib/firebase-admin";

export const runtime = "nodejs";
export const maxDuration = 60;

type ChatMessage = { role: "system" | "user" | "assistant"; content: string };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(
  data: unknown,
  status: number
): NextResponse {
  return NextResponse.json(data, { status, headers: corsHeaders });
}

export async function POST(req: NextRequest) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return json({ error: "Server misconfigured: OPENAI_API_KEY missing" }, 500);
  }

  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json(
      { error: "Missing Authorization: Bearer <Firebase ID token>" },
      401
    );
  }

  const idToken = auth.slice("Bearer ".length).trim();
  try {
    await verifyFirebaseIdToken(idToken);
  } catch {
    return json({ error: "Invalid or expired token" }, 401);
  }

  let body: { messages?: ChatMessage[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return json(
      { error: "Body must include messages: [{ role, content }, ...]" },
      400
    );
  }

  const openai = new OpenAI({ apiKey });
  const model = process.env.OPENAI_MODEL ?? "gpt-4o-mini";

  try {
    const completion = await openai.chat.completions.create({
      model,
      messages,
      max_tokens: 1024,
    });

    const text = completion.choices[0]?.message?.content ?? "";
    return json(
      {
        text,
        model: completion.model,
        usage: completion.usage,
      },
      200
    );
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "OpenAI request failed";
    return json({ error: message }, 502);
  }
}

// Optional: Flutter web / browser clients calling from another origin
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      ...corsHeaders,
      "Access-Control-Max-Age": "86400",
    },
  });
}
