# Code Explanation

## File: {{file_path}}
{{#if function_name}}## Function: {{function_name}}
{{/if}}

## Code
```{{language}}
{{code}}
```

## Explanation
{{#if context}}
### Context
{{context}}
{{/if}}

### What this code does:
1. {{#each explanation_points}}
   - {{this}}{{/each}}

{{#if related_functions}}
### Related Functions:
{{#each related_functions}}
- {{this}}{{/each}}
{{/if}}

{{#if see_also}}
### See Also:
{{#each see_also}}
- [{{this}}]({{this}})
{{/each}}
{{/if}}
