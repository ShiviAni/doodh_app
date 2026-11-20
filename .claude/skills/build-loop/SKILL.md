---
name: build-loop
description: Build-check-fix loop. Builder implements, checker verifies, failures go back to builder until ALL GREEN or a stop rule fires.
disable-model-invocation: true
---

# Build Loop

Task: $ARGUMENTS

## Steps
1. Write a one-line brief: goal | files in scope | definition of done.
2. Send the brief to the `builder` subagent.
3. Ask the `checker` subagent to run all checks.
4. ALL GREEN -> go to Finish.
5. FAILED -> send the checker's exact failure lines to `builder`
   as a fix request, then go back to step 3.
6. Say the cycle out loud: "Cycle 1/5", "Cycle 2/5" ...

Relay failures yourself. Never ask the user to forward them.

## Stop rules (check after EVERY checker run)
- ALL GREEN -> stop, show final checker output as proof.
- 5 cycles used -> stop, report what still fails + what was tried.
- Same failure two cycles in a row -> stop, escalate to the user.
- A fix broke a check that passed before -> stop, report it.

## Never
- Never report success without checker output from the last cycle.
- Never weaken, skip or delete a test or check to reach ALL GREEN.

## Finish
Show a short cycle summary, then ask: "Review the diff?"
