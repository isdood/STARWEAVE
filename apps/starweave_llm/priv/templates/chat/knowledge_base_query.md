{{#if conversation_history}}
## Conversation History:
{{#each conversation_history}}
{{role}}: {{content}}
{{/each}}
{{/if}}

## User's Question:
{{question}}

Based on the conversation history and user's question, determine if you need to search the knowledge base.
If yes, generate a search query that would help find the most relevant information.
If not, respond with "NO_SEARCH_NEEDED".
