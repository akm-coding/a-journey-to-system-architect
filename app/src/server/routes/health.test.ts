import { describe, it } from 'node:test';
import assert from 'node:assert';
import type { Request, Response, NextFunction } from 'express';

// Test the health route handler logic directly (not a full HTTP integration test).
// We create a mock request/response to verify the handler returns the expected shape.

interface RouteLayer {
  route?: {
    path: string;
    methods: { get?: boolean };
    stack: Array<{ handle: (req: Request, res: Response, next: NextFunction) => void }>;
  };
}

describe('GET /health', () => {
  it('responds with status 200 and correct body shape', async () => {
    // Dynamically import the router to get the handler
    const { default: router } = await import('./health.js');

    // Extract the GET /health handler from the router stack
    const layer = (router.stack as RouteLayer[]).find(
      (l) => l.route?.path === '/health' && l.route?.methods?.get,
    );
    assert.ok(layer?.route, 'GET /health route should exist');

    const handler = layer.route.stack[0].handle;

    // Create mock req/res
    const mockReq = {} as Request;
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
    } as unknown as Response;

    // Call the handler
    handler(mockReq, mockRes, (() => {}) as NextFunction);

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
