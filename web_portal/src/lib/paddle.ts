import { Environment, LogLevel, Paddle, type PaddleOptions } from "@paddle/paddle-node-sdk";

export function getPaddleInstance() {
  const isProd = process.env.NEXT_PUBLIC_PADDLE_ENV === "production";
  const options: PaddleOptions = {
    environment: isProd ? Environment.production : Environment.sandbox,
    logLevel: LogLevel.error,
  };
  const apiKey = process.env.PADDLE_API_KEY;
  if (!apiKey) {
    throw new Error("PADDLE_API_KEY is not set");
  }
  return new Paddle(apiKey, options);
}
