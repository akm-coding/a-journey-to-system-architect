import { describe, it } from 'node:test';
import assert from 'node:assert';

// Test the health route handler logic directly (not a full HTTP integration test).
// We create a mock request/response to verify the handler returns the expected shape.

describe('GET /health', () => {
  it('responds with status 200 and correct body shape', async () => {
    // Dynamically import the router to get the handler
    const { default: router } = await import('./health.js');

    // Extract the GET /health handler from the router stack
    const layer = router.stack.find(
      (l: { route?: { path: string; methods: { get?: boolean } } }) =>
        l.route?.path === '/health' && l.route?.methods?.get,
    );
    assert.ok(layer, 'GET /health route should exist');

    const handler = layer.route.stack[0].handle;

    // Create mock req/res
    const mockReq = {};
    let statusCode = 0;
    let responseBody: { status?: string; timestamp?: string } = {};

    const mockRes = {
      status(code: number) {
        statusCode = code;
        return mockRes;
      },
      json(body: { status?: string; timestamp?: string }) {
        responseBody = body;
        return mockRes;
      },
    };

    // Call the handler
    handler(mockReq, mockRes);

    // Verify status code
    assert.strictEqual(statusCode, 200, 'should respond with 200');

    // Verify response body has expected fields
    assert.strictEqual(responseBody.status, 'ok', 'status should be ok');
    assert.strictEqual(typeof responseBody.timestamp, 'string', 'timestamp should be a string');

    // Verify timestamp is a valid ISO string
    const parsed = new Date(responseBody.timestamp!);
    assert.ok(!isNaN(parsed.getTime()), 'timestamp should be a valid ISO date string');
  });
});
