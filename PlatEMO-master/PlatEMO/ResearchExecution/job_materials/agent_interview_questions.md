# Python Agent Developer Interview Questions

## ReAct and Tool Calling

1. What is the difference between a plain chain and a ReAct Agent?
2. How do you define tool schemas and validate tool arguments?
3. How do you prevent an Agent from calling dangerous tools?

## RAG

1. How do chunk size and overlap affect retrieval?
2. How do you evaluate whether answers are grounded?
3. When would you add reranking?

## Memory

1. What is the difference between chat history and long-term memory?
2. What should not be stored in memory?
3. How would you implement user preference memory with SQLite or Redis?

## Multi-Agent

1. When is supervisor orchestration better than handoff?
2. How do you avoid agents passing vague messages to each other?
3. What logs are needed to debug a multi-agent workflow?

## FastAPI and Async

1. Why use async for Agent services?
2. How do timeouts and retries affect tool calls?
3. When would you use StreamingResponse or WebSocket?

## Your Project Story

Use this answer structure:

1. Research problem: expensive many-objective experiments generate many result tables.
2. Engineering problem: manual analysis is slow and error-prone.
3. Solution: deterministic tools plus Agent orchestration.
4. Result: automated IGD/HV summaries, source-grounded reports, and reproducible experiment logs.
