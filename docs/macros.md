# Macros (replacement tags)

Macros are designed to support SillyTavern macros as closely as is feasible.

Macros can be used in character description, author's notes, world info and many other places and replaced with the corresponding values when generating a response. They can be used to insert dynamic content into the prompt, such as the user's name, character's description, or the current time. Macros are enclosed in double curly braces, e.g. `{{user}}` and are case-insensitive. **Please keep in mind that macro nesting is currently not supported.**

## General Macros

| Macro | Description | Ready to use |
|-------|-------------|--------------|
| `{{newline}}` | Inserts a newline. | ❌ |
| `{{trim}}` | Trims newlines surrounding this macro. | ❌ |
| `{{noop}}` | No operation, just an empty string. | ❌ |
| `{{user}}` or `<USER>` | User's name. | ✅ |
| `{{charPrompt}}` | Character's Main Prompt override. | ❌ |
| `{{charJailbreak}}` | Character's Post-History Instructions Prompt override. (NOTE: Substrate does not support 'jailbreaking'!) | ❌ |
| `{{group}}` or `{{charIfNotGroup}}` | Comma-separated list of group member names or character name in solo chats. | ❌ |
| `{{groupNotMuted}}` | Same as `{{group}}` in Substrate implementation | ❌ |
| `{{notChar}}` | Comma-separated list of all chat participants except the current speaker (`{{char}}`). In group chats this still includes muted characters, and when no message is being generated it lists every character in the roster. | ❌ |
| `{{char}}` or `<BOT>` | Character's name. | ✅ |
| `{{description}}` | Character's description. | ✅ |
| `{{scenario}}` | Character's scenario or chat scenario override (if set). | ✅ |
| `{{personality}}` | Character's personality. | ✅ |
| `{{persona}}` | User's persona description. | ❌ |
| `{{mesExamples}}` | Character's examples of dialogue (instruct-formatted). | ✅ |
| `{{mesExamplesRaw}}`  | Character's examples of dialogue (unaltered and unsplit). | ❌ |
| `{{charVersion}}` | The character's version number. | ✅ |
| `{{charDepthPrompt}}` | The character's at-depth prompt. | ❌ |
| `{{model}}` | Text generation model name for the currently selected API. **Can be inaccurate!** | ❌ |
| `{{lastMessageId}}` | Last chat message ID. | ❌ |
| `{{lastMessage}}` | Last chat message text. | ✅ |
| `{{firstIncludedMessageId}}` | The ID of the first message included in the context. Requires generation to be run at least once in the current session. | ❌ |
| `{{lastCharMessage}}` | Last chat message sent by character. | ✅ |
| `{{lastUserMessage}}` | Last chat message sent by user. | ✅ |
| `{{currentSwipeId}}` | 1-based ID of the currently displayed last message swipe. | ❌ |
| `{{lastSwipeId}}` | Number of swipes in the last chat message. | ❌ |
| `{{lastGenerationType}}` | Type of the last queued generation request. Values: "normal", "impersonate", "regenerate", "quiet", "swipe", "continue". | ❌ |
| `{{original}}` | Can be used in Prompt Overrides fields to include the default prompt from system settings. Applied to Chat Completion APIs and Instruct mode only. | ✅ |
| `{{time}}` | Current system time. | ✅ |
| `{{time_UTC±X}}` | Current time in the specified UTC offset (timezone), e.g. for UTC+02:00 use `{{time_UTC+2}}`. | ✅ |
| `{{timeDiff::(time1)::(time2)}}` | The time difference between time1 and time2. Accepts time and date macros. | ❌ |
| `{{date}}` | Current system date. | ✅ |
| `{{input}}` | Contents of the user input bar. | ❌ |
| `{{weekday}}` | The current weekday. | ✅ |
| `{{isotime}}` | The current ISO time (24-hour clock). | ✅ |
| `{{isodate}}` | The current ISO date (YYYY-MM-DD). | ✅ |
| `{{datetimeformat ...}}` | Current date/time in specified format (e.g. `{{datetimeformat DD.MM.YYYY HH:mm}}`). | ✅ |
| `{{idle_duration}}` | Inserts a humanized string of the time range since the last user message was sent (examples: 4 hours, 1 day). | ❌ |
| `{{random:(args)}}` | Returns a random item from the list (e.g. `{{random:1,2,3,4}}` will return 1 of the 4 numbers at random). | ❌ |
| `{{random::arg1::arg2}}` | Alternate syntax for random that supports commas in its arguments. | ❌ |
| `{{pick::(args)}}` | Alternative to random, but the selected argument is stable on subsequent evaluations in the current chat if the source string remains unchanged. | ❌ |
| `{{roll:(formula)}}` | Generates a random value using D&D dice syntax: XdY+Z (e.g. `{{roll:d6}}` generates a value 1-6). | ❌ |
| `{{bias "text here"}}` | Sets a behavioral bias for the AI until the next user input. Quotes around text are required. | ❌ |
| `{{// (note)}}` | Allows leaving a note that will be replaced with blank content. Not visible for the AI. | ❌ |
| `{{reverse:(content)}}` | Reverses the content of the macro. | ❌ |

## Instruct Mode and Context Template Macros

(Substrate focuses on chat models. Instruct mode is currently not supported)

## Chat variables Macros

- Local variables = unique to the current chat
- Global variables = works in any chat for any character

| Macro | Description | Ready to use |
|-------|-------------|--------------|
| `{{getvar::name}}` | Replaced with the value of the local variable "name". | ✅ |
| `{{setvar::name::value}}` | Replaced with empty string, sets the local variable "name" to "value". Allows empty values. | ❌ |
| `{{addvar::name::increment}}` | Replaced with empty string, adds a numeric value of "increment" to the local variable "name". | ❌ |
| `{{incvar::name}}` | Replaced with the result of incrementing the value of variable "name" by 1. | ❌ |
| `{{decvar::name}}` | Replaced with the result of decrementing the value of variable "name" by 1. | ❌ |
| `{{getglobalvar::name}}` | Replaced with the value of the global variable "name". | ✅ |