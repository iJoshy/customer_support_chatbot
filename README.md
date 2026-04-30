# Meridian Electronics Customer Support Chatbot

A production-shaped hackathon prototype for Meridian Electronics support. The app connects an LLM-powered chat experience to Meridian's internal order MCP server so customers can search products, check inventory, authenticate with email/PIN, view order history, and place orders.

## What It Does

- Discovers MCP tools from `https://order-mcp-74afyau24q-uc.a.run.app/mcp`
- Uses Bedrock Nova as a cost-conscious LLM backend
- Calls MCP tools for product, customer, and order workflows
- Preserves session memory and authenticated customer state
- Guards protected tools so order history and order creation require customer verification
- Provides a Next.js chat UI with demo prompts for the final presentation

## MCP Tools

The backend discovers these tools at runtime:

- `list_products`
- `get_product`
- `search_products`
- `get_customer`
- `verify_customer_pin`
- `list_orders`
- `get_order`
- `create_order`


## Local Development

Backend:

```bash
cd backend
uv run server.py
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:3000`.

## Environment

Copy `.env.example` to `.env` and set:

```env
DEFAULT_AWS_REGION=us-east-1
BEDROCK_MODEL_ID=global.amazon.nova-2-lite-v1:0
MCP_SERVER_URL=https://order-mcp-74afyau24q-uc.a.run.app/mcp
CORS_ORIGINS=http://localhost:3000
USE_S3=false
MEMORY_DIR=../memory
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## Architecture

```text
Browser / Next.js
   |
   | POST /chat
   v
FastAPI backend
   |
   +--> AWS Bedrock Converse API
   |
   +--> MCP Streamable HTTP server
   |      - product search
   |      - customer verification
   |      - order lookup
   |      - order creation
   |
   +--> local JSON or S3 session memory
```

## Useful Demo Script

1. Ask: `I need a 27-inch monitor. What do you have in stock?`
2. Authenticate: `My email is donaldgarcia@example.net and my PIN is 7912.`
3. Ask: `Show my recent orders.`
4. Ask: `I want to order 2 units of MON-0054.`
5. Confirm only after the bot summarizes price, stock, and total.

## Verification Done

- Python syntax check passed for backend files.
- Next.js production build passed.
- `/health` works locally.
- `/tools` discovers all MCP tools.
- Product search chat flow works through Bedrock and MCP.
- Authenticated order history flow works through Bedrock and MCP.
