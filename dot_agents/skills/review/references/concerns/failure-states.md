# Failure States

Load when changed code handles failure or terminal status: `catch`/`.catch`, ignored exit status, unchecked SDK result, `Promise.allSettled`, retry or timeout config, placeholder returns, `status`/`state`/`outcome` values, or `done`/`healthy`/`configured`/`cached`/`skip` markers.

**Expected absence, business rejection, retryable failure, waiting, logic error, partial work, and success must stay observably distinct.** Collapsing any two into one value or message hides a real outcome behind a plausible one.

A guard that returns `null`, `undefined`, `false`, or `[]` must not hide a failure the caller needs. For `state`, `status`, and `outcome`, check explicit success rather than treating not-error as success.

Before a flow records `done`, `success`, `healthy`, `configured`, or any final marker, confirm every required durable write and external side effect has completed. A successful first attempt is not proof of retry behavior, a retryable intermediate state is not a terminal failure, and the final exhausted state must keep enough context for an operator to act.
