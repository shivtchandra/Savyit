import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { verifyFirebaseIdToken } from "@/lib/firebase-admin";

export const runtime = "nodejs";
export const maxDuration = 60;

type ChatMessage = {
  role: "system" | "user" | "assistant" | string;
  content: string;
};

type ChatBody = {
  messages?: ChatMessage[];
  model?: string;
  temperature?: number;
  max_tokens?: number;
};

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

  let body: ChatBody;
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
  const model =
    body.model?.trim() ||
    process.env.OPENAI_MODEL ||
    "gpt-4o-mini";

  const maxTokens = body.max_tokens ?? 4096;
  const temperature = body.temperature;

  try {
    const completion = await openai.chat.completions.create({
      model,
      messages: messages as OpenAI.Chat.ChatCompletionMessageParam[],
      max_tokens: maxTokens,
      ...(temperature !== undefined ? { temperature } : {}),
    });

    // OpenAI-compatible shape for existing Flutter parsers (choices[0].message.content).
    const payload = {
      id: completion.id,
      object: completion.object,
      created: completion.created,
      model: completion.model,
      choices: completion.choices.map((ch) => ({
        index: ch.index,
        message: {
          role: ch.message.role,
          content: ch.message.content ?? "",
        },
        finish_reason: ch.finish_reason,
      })),
      usage: completion.usage
        ? {
            prompt_tokens: completion.usage.prompt_tokens,
            completion_tokens: completion.usage.completion_tokens,
            total_tokens: completion.usage.total_tokens,
          }
        : undefined,
    };
    return json(payload, 200);
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
