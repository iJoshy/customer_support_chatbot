'use client';

import { useEffect, useRef, useState } from 'react';
import { Bot, CheckCircle2, Loader2, PackageSearch, ReceiptText, Send, ShieldCheck, ShoppingCart, User } from 'lucide-react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

const suggestions = [
  {
    icon: PackageSearch,
    label: 'Find monitors',
    prompt: 'I need a 27-inch monitor. What do you have in stock?',
  },
  {
    icon: ShieldCheck,
    label: 'Sign in',
    prompt: 'My email is donaldgarcia@example.net and my PIN is 7912.',
  },
  {
    icon: ReceiptText,
    label: 'Order history',
    prompt: 'Show my recent orders.',
  },
  {
    icon: ShoppingCart,
    label: 'Place order',
    prompt: 'I want to order 2 units of MON-0054.',
  },
];

function sanitizeAssistantContent(content: string): string {
  if (!content) return '';
  let cleaned = content.replace(/<(thinking|analysis|reasoning)>[\s\S]*?<\/\1>/gi, '');
  cleaned = cleaned.replace(/<\/?(thinking|analysis|reasoning)\b[^>]*>/gi, '');
  return cleaned.trim();
}

export default function Twin() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isLoading]);

  const sendMessage = async (override?: string) => {
    const content = (override ?? input).trim();
    if (!content || isLoading) return;

    const userMessage: Message = {
      id: crypto.randomUUID(),
      role: 'user',
      content,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: content,
          session_id: sessionId || undefined,
        }),
      });

      if (!response.ok) {
        const detail = await response.text();
        throw new Error(detail || 'Failed to send message');
      }

      const data = await response.json();
      if (!sessionId) setSessionId(data.session_id);

      setMessages((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: sanitizeAssistantContent(data.response),
          timestamp: new Date(),
        },
      ]);
    } catch (error) {
      console.error(error);
      setMessages((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: 'I could not reach the support service. Please try again in a moment.',
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsLoading(false);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      sendMessage();
    }
  };

  return (
    <section className="grid min-h-[720px] grid-cols-1 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm lg:grid-cols-[320px_1fr]">
      <aside className="border-b border-slate-200 bg-slate-950 p-5 text-white lg:border-b-0 lg:border-r">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-md bg-emerald-500 text-slate-950">
            <Bot className="h-6 w-6" />
          </div>
          <div>
            <h1 className="text-lg font-semibold">Meridian Assist</h1>
            <p className="text-sm text-slate-300">Customer support chatbot</p>
          </div>
        </div>

        <div className="mt-6 space-y-3 text-sm text-slate-300">
          <div className="flex items-start gap-2">
            <CheckCircle2 className="mt-0.5 h-4 w-4 text-emerald-400" />
            <span>Connected to the order MCP service for live products, inventory, and orders.</span>
          </div>
          <div className="flex items-start gap-2">
            <ShieldCheck className="mt-0.5 h-4 w-4 text-emerald-400" />
            <span>Returning customers authenticate with email and PIN before order access.</span>
          </div>
        </div>

        <div className="mt-7">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Demo prompts</p>
          <div className="mt-3 grid gap-2">
            {suggestions.map(({ icon: Icon, label, prompt }) => (
              <button
                key={label}
                type="button"
                onClick={() => sendMessage(prompt)}
                disabled={isLoading}
                className="flex items-center gap-3 rounded-md border border-slate-700 bg-slate-900 px-3 py-2 text-left text-sm text-slate-100 transition hover:border-emerald-400 hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
              >
                <Icon className="h-4 w-4 text-emerald-400" />
                <span>{label}</span>
              </button>
            ))}
          </div>
        </div>
      </aside>

      <div className="flex min-h-[620px] flex-col bg-slate-50">
        <header className="border-b border-slate-200 bg-white px-5 py-4">
          <h2 className="text-base font-semibold text-slate-950">Live support session</h2>
          <p className="text-sm text-slate-500">Ask about product availability, order history, or placing an order.</p>
        </header>

        <div className="flex-1 overflow-y-auto px-4 py-5">
          {messages.length === 0 && (
            <div className="mx-auto mt-16 max-w-md text-center">
              <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-md bg-emerald-100 text-emerald-700">
                <PackageSearch className="h-7 w-7" />
              </div>
              <h3 className="mt-4 text-lg font-semibold text-slate-950">How can Meridian help today?</h3>
              <p className="mt-2 text-sm text-slate-500">
                Try searching for a product, signing in with a demo customer, or creating an order.
              </p>
            </div>
          )}

          <div className="space-y-4">
            {messages.map((message) => (
              <div key={message.id} className={`flex gap-3 ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                {message.role === 'assistant' && (
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-emerald-600 text-white">
                    <Bot className="h-5 w-5" />
                  </div>
                )}

                <div
                  className={`max-w-[78%] rounded-lg px-4 py-3 text-sm leading-6 ${
                    message.role === 'user'
                      ? 'bg-slate-900 text-white'
                      : 'border border-slate-200 bg-white text-slate-800'
                  }`}
                >
                  <p className="whitespace-pre-wrap">{message.role === 'assistant' ? sanitizeAssistantContent(message.content) : message.content}</p>
                  <p className={`mt-2 text-xs ${message.role === 'user' ? 'text-slate-300' : 'text-slate-400'}`}>
                    {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>

                {message.role === 'user' && (
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-slate-700 text-white">
                    <User className="h-5 w-5" />
                  </div>
                )}
              </div>
            ))}

            {isLoading && (
              <div className="flex gap-3">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-emerald-600 text-white">
                  <Bot className="h-5 w-5" />
                </div>
                <div className="flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-4 py-3 text-sm text-slate-500">
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Checking Meridian systems
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>
        </div>

        <form
          className="border-t border-slate-200 bg-white p-4"
          onSubmit={(event) => {
            event.preventDefault();
            sendMessage();
          }}
        >
          <div className="flex gap-2">
            <input
              ref={inputRef}
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={onKeyDown}
              placeholder="Type a product, order, or account question..."
              disabled={isLoading}
              className="min-w-0 flex-1 rounded-md border border-slate-300 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100 disabled:bg-slate-100"
              autoFocus
            />
            <button
              type="submit"
              disabled={!input.trim() || isLoading}
              className="flex h-12 w-12 shrink-0 items-center justify-center rounded-md bg-emerald-600 text-white transition hover:bg-emerald-700 disabled:cursor-not-allowed disabled:bg-slate-300"
              aria-label="Send message"
            >
              <Send className="h-5 w-5" />
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}
