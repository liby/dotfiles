# Tests

Load when changed code adds, deletes, or rewrites tests, fixtures, mocks, snapshots, harnesses, or test-only guards, or when a review claim relies on tests as evidence.

**Tests are contract evidence, not a coverage quota.** A test finding is reportable only when the test proves, hides, or fails to cover a real behavior, boundary, or data contract risk. Read the validation config before trusting a typecheck, lint, or test result.

## Compare the fixture to a reachable shape

When a fixture, mock, factory, snapshot, or fake response defines the shape under test, compare it with the source-owned schema, provider payload, framework path, browser event, DB row, queue payload, or CLI output. Prefer reachable shapes and values outside the happy fixture; an impossible mock-only shape should not justify a guard, fallback, or test. Flag fixture-specific hardcoding that satisfies the example without implementing the invariant.

## A test must fail when the invariant breaks

When a test covers an error path, rejection, permission check, retry, deletion, fallback, skipped side effect, or user-visible message, it should assert the observable status, message, return value, durable state, or external call that distinguishes that branch. Existence-only assertions are valid only when existence is the contract. Require a test where an untested branch can silently pass, leak data, corrupt state, or make a false success claim; for a bug fix, the test should fail before the fix.

## Verify the boundary the test cannot reach

When behavior depends on browser hydration, iframe or session state, framework routing, middleware matching, sandbox lifecycle, provider protocol, DB semantics, durable replay, or installed CLI or runtime behavior, verify the boundary owner. Handler calls, hook mocks, and unit fakes prove pure logic only; mark manual or runtime verification when the real boundary is not encoded locally. Unit tests suffice for pure transforms, parsers, validators, and state machines when their input contract is source-owned. Reuse source-owned constants and schemas instead of duplicating domain lists or protocol shapes in the test.

## Keep the test at the owner

When a narrow change adds broad setup, new helpers, custom factories, or fixtures, keep the test at the owner that proves the invariant. Snapshot and golden-file tests are useful for stable generated output, but they are weak evidence for behavior whose real contract is a state transition, access decision, or runtime boundary.
