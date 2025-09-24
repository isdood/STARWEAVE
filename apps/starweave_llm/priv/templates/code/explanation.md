# Code Explanation

File: {{file_path}}
<%= if @function_name && @function_name != "" do %>
Function: <%= @function_name %>
<% end %>
Language: {{language}}

## Grounding Rules
- Only use the code provided below as your source of truth.
- Do not speculate or assume behavior that is not visible in the code.
- If something is not present in the code, explicitly say: "Not in the provided code.".
- Prefer citing exact identifiers and quoting short relevant lines.

<%= if @context && @context != "" do %>
### Additional Context
<%= @context %>
<% end %>

## Code
```<%= @language %>
<%= @code %>
```

## Summary
- What this module/file does.
- How data flows through key functions.
- How errors are handled and what is persisted.

## Key Responsibilities
- Describe main responsibilities and data structures.
- Highlight external modules/APIs used.

## Important Functions and Behavior
- Explain main public functions, inputs/outputs, and side effects.
- Note concurrency, persistence, and retrieval patterns if visible.

## Limitations and Unknowns
- List any information that is not inferable from the code, using the phrase: "Not in the provided code.".

## Related Items
<%= if is_list(@related_functions) and length(@related_functions) > 0 do %>
- Related Functions:
<%= Enum.map_join(@related_functions, "\n", fn f -> "  - " <> to_string(f) end) %>
<% end %>

<%= if is_list(@see_also) and length(@see_also) > 0 do %>
- See Also:
<%= Enum.map_join(@see_also, "\n", fn s -> "  - " <> to_string(s) end) %>
<% end %>
